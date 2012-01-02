class GroupsController < ApplicationController
  before_filter :authenticate_user!, :except => [:show]

  # respond_to :html, :except => [:tag_index]
  # respond_to :json, :only => [:index, :show]
  # respond_to :js, :only => [:tag_index]

  rescue_from ActiveRecord::RecordNotFound do
    render :file => "#{Rails.root}/public/404.html", :layout => false, :status => 404
  end

  def index
    @group = Group.new
  end

  def create
    attribs = params['group']
    if attribs.nil?
      return redirect_to(:back)
    end
    attribs.delete_if { |k,v|
      ! [
        'identifier',
        'name',
        'description',
      ].include? k
    }

    @group = Group.create(attribs)
    if @group.valid?
      current_user.groups << @group
      membership = @group.group_members[0]
      membership.admin = true
      membership.save
      redirect_to group_by_identifier_path(@group.identifier)
    else
      if @group.errors.values.flatten.grep(/has already been taken/).any?
        flash[:error] = t('groups.create.already_exists')
      else
        flash[:error] = t('groups.create.failed')
      end
      render :index
    end
  end

  def show
    if params[:id]
      @group = Group.find_by_id( params[:id].to_i )
    elsif params[:identifier]
      @group = Group.find_by_identifier( params[:identifier] )
    end
    if @group.nil?
      return redirect_to(:back)
    end

    @stream = Stream::Group.new(current_user, @group.identifier, :max_time => max_time, :page => params[:page])
  end

  def edit
    @group = Group.find_by_id( params[:id].to_i )
    if @group.nil? || ! current_user.admin_of?(@group)
      return redirect_to(:back)
    end
  end

  def update
    group = Group.find_by_id( params[:id].to_i )
    if group.nil? || ! current_user.admin_of?(group)
      return redirect_to(:back)
    end

    attribs = params['group']
    group.update_attributes(
      :name        => attribs['name'],
      :description => attribs['description']
    )

    flash[:notice] = t('groups.update.success')
    redirect_to group_path(group)
  end

  def join
    group = Group.find_by_id( params[:group_id].to_i )
    if group.nil?
      return redirect_to(:back)
    end

    if current_user.member_of?(group)
      flash[:error] = t('groups.join.already_member')
    elsif group.admission == 'on-approval'
      group.membership_requests.create!( :person_id => current_user.person.id )
      flash[:notice] = t('groups.join.pending')
    elsif group.admission == 'open'
      group.members << current_user.person
      flash[:notice] = t('groups.join.success', :name => group.name)
    end

    redirect_to :back
  end

  def approve_request
    group = Group.find_by_id( params['group_id'].to_i )
    if group.nil? || ! current_user.admin_of?(group)
      return redirect_to(:back)
    end

    request = group.membership_requests.find_by_person_id( params['id'].to_i )
    if request.nil?
      return redirect_to(:back)
    end

    group.members << request.person
    request.destroy
    flash[:notice] = t('groups.approve_request.success', :whom => request.person.diaspora_handle)

    redirect_to :back
  end

  def reject_request
    group = Group.find_by_id( params['group_id'].to_i )
    if group.nil? || ! current_user.admin_of?(group)
      return redirect_to(:back)
    end

    request = group.membership_requests.find_by_person_id( params['id'].to_i )
    if request.nil?
      return redirect_to(:back)
    end

    request.destroy
    flash[:notice] = t('groups.reject_request.success', :whom => request.person.diaspora_handle)

    redirect_to :back
  end
end
