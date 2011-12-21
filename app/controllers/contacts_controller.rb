#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class ContactsController < ApplicationController
  before_filter :authenticate_user!

  def index
    @contacts = case params[:set]
    when "only_sharing"
      current_user.contacts.only_sharing
    when "all"
      current_user.contacts
    else
      if params[:a_id]
        @aspect = current_user.aspects.find(params[:a_id])
        @aspect.contacts
      else
        current_user.contacts.receiving
      end
    end

    respond_to do |format|
      format.html { @contacts = sort_and_paginate_profiles(@contacts) }
      format.mobile { @contacts = sort_and_paginate_profiles(@contacts) }
      format.json {
        @people = Person.for_json.joins(:contacts => :aspect_memberships).
          where(:contacts => { :user_id => current_user.id },
                :aspect_memberships => { :aspect_id => params[:aspect_ids] })

        render :json => @people.to_json
      }
    end
  end

  def sharing
    @contacts = current_user.contacts.sharing.includes(:aspect_memberships)
    render :layout => false
  end

  def spotlight
    @spotlight = true
    @people = Person.community_spotlight
  end

  def import
    file = params['file']
    if file.nil?
      redirect_to :back
      return
    end

    num_in_file = 0
    num_already = 0
    num_added = 0
    aspect = current_user.aspects.first
    doc = Nokogiri::XML( file.read )
    doc.xpath('/export/contacts/contact').each do |node|
      num_in_file += 1
      person = Person.find_by_guid( node.at_xpath('person_guid').content.strip )
      next  if person.nil?

      added = false
      already_added = false
      node.xpath('aspects/aspect').each do |node_aspect|
        aspect = current_user.aspects.find_or_create_by_name( node_aspect.content.strip )
        if aspect && aspect.valid?
          if aspect.contacts.where(:person_id => person.id).any?
            already_added = true
          else
            current_user.share_with  person, aspect
            added = true
          end
        end
      end

      if added
        num_added += 1
      elsif already_added
        num_already += 1
      end
    end

    message = I18n.t('.contacts.import.imported', :num_added => num_added, :num_in_file => num_in_file)
    if num_already > 0
      message << ' ' << I18n.t('.contacts.import.already_added', :num_already => num_already)
    end
    flash[:notice] = message
    redirect_to contacts_path
  end

  private

  def sort_and_paginate_profiles contacts
    contacts.
      includes(:aspects, :person => :profile).
      order('profiles.last_name ASC').
      paginate(:page => params[:page], :per_page => 25)
  end
end
