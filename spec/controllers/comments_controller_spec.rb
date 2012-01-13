#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe CommentsController do
  before do
    @controller.stub(:current_user).and_return(alice)
    sign_in :user, alice
  end

  describe '#create' do
    let(:comment_hash) {
      {:text    =>"facebook, is that you?",
       :post_id =>"#{@post.id}"}
    }

    context "on my own post" do
      before do
        aspect_to_post = alice.aspects.where(:name => "generic").first
        @post = alice.post :status_message, :text => 'GIANTS', :to => aspect_to_post
      end

      it 'responds to format js' do
        post :create, comment_hash.merge(:format => 'js')
        response.code.should == '201'
        response.body.should match comment_hash[:text]
      end
      it 'responds to format mobile' do
        post :create, comment_hash.merge(:format => 'mobile')
        response.should be_success
      end
    end

    context "on a post from a contact" do
      before do
        aspect_to_post = bob.aspects.where(:name => "generic").first
        @post = bob.post :status_message, :text => 'GIANTS', :to => aspect_to_post
      end

      it 'comments' do
        post :create, comment_hash
        response.code.should == '201'
      end

      it "doesn't overwrite author_id" do
        new_user = Factory.create(:user)
        comment_hash[:author_id] = new_user.person.id.to_s
        post :create, comment_hash
        Comment.find_by_text(comment_hash[:text]).author_id.should == alice.person.id
      end

      it "doesn't overwrite id" do
        old_comment = alice.comment("hello", :post => @post)
        comment_hash[:id] = old_comment.id
        post :create, comment_hash
        old_comment.reload.text.should == 'hello'
      end
    end

    it 'posts no comment on a post from a stranger' do
      aspect_to_post = eve.aspects.where(:name => "generic").first
      @post = eve.post :status_message, :text => 'GIANTS', :to => aspect_to_post

      alice.should_not_receive(:comment)
      post :create, comment_hash
      response.code.should == '422'
    end
  end

  describe '#destroy' do
    before do
      aspect_to_post = bob.aspects.where(:name => "generic").first
      @message = bob.post(:status_message, :text => "hey", :to => aspect_to_post)
    end

    context 'your post' do
      before do
        @controller.stub(:current_user).and_return(bob)
        sign_in :user, bob
      end

      it 'lets the user delete his comment' do
        comment = bob.comment("hey", :post => @message)

        bob.should_receive(:retract).with(comment)
        delete :destroy, :format => "js", :post_id => 1,  :id => comment.id
        response.status.should == 204
      end

      it "lets the user destroy other people's comments" do
        comment = alice.comment("hey", :post => @message)

        bob.should_receive(:retract).with(comment)
        delete :destroy, :format => "js", :post_id => 1,  :id => comment.id
        response.status.should == 204
      end
    end

    context "another user's post" do
      it 'let the user delete his comment' do
        comment = alice.comment("hey", :post => @message)

        alice.should_receive(:retract).with(comment)
        delete :destroy, :format => "js", :post_id => 1,  :id => comment.id
        response.status.should == 204
      end

      it 'does not let the user destroy comments he does not own' do
        comment1 = bob.comment("hey", :post => @message)
        comment2 = eve.comment("hey", :post => @message)

        alice.should_not_receive(:retract).with(comment1)
        delete :destroy, :format => "js", :post_id => 1,  :id => comment2.id
        response.status.should == 403
      end
    end

    it 'renders nothing and 404 on a nonexistent comment' do
      delete :destroy, :post_id => 1, :id => 343415
      response.status.should == 404
      response.body.strip.should be_empty
    end
  end

  describe '#index' do
    before do
      aspect_to_post = bob.aspects.where(:name => "generic").first
      @message = bob.post(:status_message, :text => "hey", :to => aspect_to_post.id)
    end

    it 'generates a jasmine fixture', :fixture => true do
      2.times { alice.comment("hey", :post => @message) }
      get :index, :post_id => @message.id

      save_fixture(response.body, "ajax_comments_on_post")
    end

    it 'works for mobile' do
      get :index, :post_id => @message.id, :format => 'mobile'
      response.should be_success
    end

    describe 'given some comments on a post' do
      before do
        @comments = [alice, bob, eve].map{ |u| u.comment("hey", :post => @message) }
      end

      it 'returns all the comments for a post by default' do
        get :index, :post_id => @message.id, :format => 'js'
        assigns[:comments].should == @comments
      end

      it 'returns the last n comments if num is specified' do
        get :index, :post_id => @message.id, :num => 2, :format => 'js'
        assigns[:comments].should == @comments[-2..-1]
      end
    end

    it 'returns a 404 on a nonexistent post' do
      get :index, :post_id => 235236, :format => 'js'
      response.status.should == 404
    end

    it 'returns a 404 on a post that is not visible to the signed in user' do
      aspect_to_post = eve.aspects.where(:name => "generic").first
      message = eve.post(:status_message, :text => "hey", :to => aspect_to_post.id)
      bob.comment("hey", :post => @message)
      get :index, :post_id => message.id, :format => 'js'
      response.status.should == 404
    end
  end
end
