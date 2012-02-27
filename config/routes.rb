#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

Diaspora::Application.routes.draw do


  # Posting and Reading

  resources :reshares

  resources :aspects do
    put :toggle_contact_visibility
  end

  resources :status_messages, :only => [:new, :create]

  resources :posts, :only => [:show, :destroy] do
    resources :likes, :only => [:create, :destroy, :index]
    resources :comments, :only => [:new, :create, :destroy, :index]
  end
  get 'p/:id' => 'posts#show', :as => 'short_post'
  get 'public_stream' => 'posts#index', :as => 'public_stream'
  post 'preview' => 'posts#preview'
  post 'comment_preview' => 'comments#preview'
  get 'search_posts' => 'posts#search'
  # roll up likes into a nested resource above
  resources :comments, :only => [:create, :destroy] do
    resources :likes, :only => [:create, :destroy, :index]
  end

  resources :groups do
    resources :members, :controller => 'group_members', :only => [:create, :destroy,]
    post 'join'
    post 'approve/:id', :action => 'approve_request', :as => 'approve_membership_request'
    delete 'reject/:id', :action => 'reject_request', :as => 'reject_membership_request'
  end
  get '/g/:identifier' => 'groups#show', :as => 'group_by_identifier'
  post 'groups/clear_photo' => 'groups#clear_photo'

  get 'bookmarklet' => 'status_messages#bookmarklet'

  resources :photos, :except => [:index] do
    put :make_profile_photo
  end

  # ActivityStreams routes
  scope "/activity_streams", :module => "activity_streams", :as => "activity_streams" do
    resources :photos, :controller => "photos", :only => [:create]
  end

  resources :conversations do
    resources :messages, :only => [:create, :show]
    delete 'visibility' => 'conversation_visibilities#destroy'
  end

  resources :notifications, :only => [:index, :update] do
    get :read_all, :on => :collection
  end
  get 'notifications/num_unread' => 'notifications#num_unread'# , :as => 'num_unread_notifications'

  resources :tags, :only => [:index]
  scope "tags/:name" do
    post   "tag_followings" => "tag_followings#create", :as => 'tag_tag_followings'
    delete "tag_followings" => "tag_followings#destroy"
  end

  post   "multiple_tag_followings" => "tag_followings#create_multiple", :as => 'multiple_tag_followings'

  get "tag_followings" => "tag_followings#index", :as => 'tag_followings'
  resources :mentions, :only => [:index]
  resources "tag_followings", :only => [:create]
  resources 'tag_exclusions', :only => [:create, :destroy]

  get 'comment_stream' => 'comment_stream#index', :as => 'comment_stream'

  get 'like_stream' => 'like_stream#index', :as => 'like_stream'

  get 'tags/:name' => 'tags#show', :as => 'tag'

  resources :apps, :only => [:show]

  #Cubbies info page
  resource :token, :only => :show


  # Users and people

  resource :user, :only => [:edit, :update, :destroy], :shallow => true do
    get :getting_started_completed
    get :export
    get :export_photos
    get :generate_api_token
  end

  controller :users do
    get 'public/:username'          => :public,           :as => 'users_public'
    match 'getting_started'         => :getting_started,  :as => 'getting_started'
    match 'privacy'                 => :privacy_settings, :as => 'privacy_settings'
    get 'filters'                   => :filters,          :as => 'filters'
    get 'getting_started_completed' => :getting_started_completed
    get 'confirm_email/:token'      => :confirm_email,    :as => 'confirm_email'
  end

  # This is a hack to overide a route created by devise.
  # I couldn't find anything in devise to skip that route, see Bug #961
  match 'users/edit' => redirect('/user/edit')

  devise_for :users, :controllers => {:registrations => "registrations",
                                      :password      => "devise/passwords",
                                      :sessions      => "sessions",
                                      :invitations   => "invitations"} do
    get 'invitations/resend/:id' => 'invitations#resend', :as => 'invitation_resend'
    get 'invitations/email' => 'invitations#email', :as => 'invite_email'
  end

  get 'login' => redirect('/users/sign_in')

  scope 'admins', :controller => :admins do
    match :user_search
    get   :admin_inviter
    get   :weekly_user_stats
    get   :correlations
    get   :stats, :as => 'pod_stats'
  end

  resource :profile, :only => [:edit, :update]

  resources :contacts,           :except => [:update, :create] do
    get :sharing, :on => :collection
  end
  resources :aspect_memberships, :only  => [:destroy, :create, :update]
  resources :share_visibilities,  :only => [:update]
  resources :blocks, :only => [:create, :destroy]

  get 'spotlight' => 'community_spotlight#index', :as => 'spotlight'

  get 'community_spotlight' => "contacts#spotlight", :as => 'community_spotlight'
  post '/contacts/import' => 'contacts#import', :as => 'contacts_import'

  get 'stream' => "multis#index", :as => 'multi'

  resources :people, :except => [:edit, :update] do
    resources :status_messages
    resources :photos
    get  :contacts
    get "aspect_membership_button" => :aspect_membership_dropdown, :as => "aspect_membership_button"
    collection do
      post 'by_handle' => :retrieve_remote, :as => 'person_by_handle'
      get :tag_index
    end
  end
  get '/u/:username' => 'people#show', :as => 'user_profile'
  get '/u/:username/profile_photo' => 'users#user_photo'

  resources :chat_messages
  post '/chat_messages_mark_conversation_read' => 'chat_messages#mark_conversation_read'
  get '/chat_messages_new_conversation' => 'chat_messages#new_conversation'
  get '/update_chat_status' => 'users#update_chat_status'
  get '/chat_conversation/:recipient_id' => 'chat_messages#show_conversation', :as => 'show_chat_conversation'

  # Federation

  controller :publics do
    get 'webfinger'             => :webfinger
    get 'hcard/users/:guid'     => :hcard
    get '.well-known/host-meta' => :host_meta
    post 'receive/users/:guid'  => :receive
    post 'receive/public'       => :receive_public
    get 'hub'                   => :hub
  end



  # External

  resources :authorizations, :only => [:index, :destroy]
  scope "/oauth", :controller => :authorizations, :as => "oauth" do
    get "authorize" => :new
    post "authorize" => :create
    post :token
  end

  resources :services, :only => [:index, :destroy]
  controller :services do
    scope "/auth", :as => "auth" do
      match ':provider/callback' => :create
      match :failure
    end
    scope 'services' do
      match 'inviter/:provider' => :inviter, :as => 'service_inviter'
      match 'finder/:provider'  => :finder,  :as => 'friend_finder'
    end
  end

  scope 'api/v0', :controller => :apis do
    get :me
  end

  namespace :api do
    namespace :v0 do
      get "/users/:username" => 'users#show', :as => 'user'
      get "/tags/:name" => 'tags#show', :as => 'tag'
    end
  end

  namespace 'fapi' do
    namespace 'v0' do
      resource 'me', :only => [:show,], :controller => :me
      resources 'aspects', :only => [:index,]
      resources 'posts', :only => [:index, :create,]
      resources 'notifications', :only => [:index,]
    end
  end

  # Mobile site

  get 'mobile/toggle', :to => 'home#toggle_mobile', :as => 'toggle_mobile'

  #Protocol Url
  get 'protocol' => redirect("https://github.com/diaspora/diaspora/wiki/Diaspora%27s-federation-protocol")

  # Resque web
  if AppConfig[:mount_resque_web]
    mount Resque::Server.new, :at => '/resque-jobs', :as => "resque_web"
  end

  # Logout Page (go mobile)
  get 'logged_out' => 'users#logged_out', :as => 'logged_out'

  # Startpage
  root :to => 'home#show'

  get 'privacy_info', :to => 'home#privacy_info', :as => 'privacy_info'
end
