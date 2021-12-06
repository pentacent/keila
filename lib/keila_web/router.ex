defmodule KeilaWeb.Router do
  use KeilaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {KeilaWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug KeilaWeb.Meta.Plug
    plug KeilaWeb.AuthSession.Plug
  end

  # Non-authenticated Routes
  scope "/", KeilaWeb do
    pipe_through :browser

    get "/verify-sender/:token", SenderController, :verify_from_token
    get "/verify-sender/c/:token", SenderController, :cancel_verification_from_token
  end

  # Unauthenticated Routes
  scope "/", KeilaWeb do
    pipe_through [:browser, KeilaWeb.AuthSession.RequireNoAuthPlug]

    get "/auth/login", AuthController, :login
    post "/auth/login", AuthController, :post_login
    get "/auth/register", AuthController, :register
    post "/auth/register", AuthController, :post_register
    get "/auth/activate/:token", AuthController, :activate
    get "/auth/reset", AuthController, :reset
    post "/auth/reset", AuthController, :post_reset
    get "/auth/reset/:token", AuthController, :reset_change_password
    post "/auth/reset/:token", AuthController, :post_reset_change_password
  end

  # Activation Routes
  pipeline :activation do
    plug KeilaWeb.AuthSession.RequireAuthPlug, allow_not_activated: true
  end

  scope "/", KeilaWeb do
    pipe_through [:browser, :activation]

    get "/auth/activate", AuthController, :activate_required
    post "/auth/activate", AuthController, :post_activate_resend
  end

  # Authenticated Routes without a Project context
  scope "/", KeilaWeb do
    pipe_through [:browser, KeilaWeb.AuthSession.RequireAuthPlug]

    get "/auth/logout", AuthController, :logout

    get "/account", AccountController, :edit
    put "/account", AccountController, :post_edit
    get "/account/await-subscription", AccountController, :await_subscription

    get "/", ProjectController, :index
    get "/projects/new", ProjectController, :new
    post "/projects/new", ProjectController, :post_new

    get "/admin/users", UserAdminController, :index
    delete "/admin/users", UserAdminController, :delete
    get "/admin/users/:id/impersonate", UserAdminController, :impersonate
    get "/admin/users/:id/credits", UserAdminController, :show_credits
    post "/admin/users/:id/credits", UserAdminController, :create_credits

    resources "/admin/shared-senders", SharedSenderAdminController
    get "/admin/shared-senders/:id/delete", SharedSenderAdminController, :delete_confirmation
  end

  # Authenticated Routes within a Project context
  scope "/", KeilaWeb do
    pipe_through [:browser, KeilaWeb.AuthSession.RequireAuthPlug, KeilaWeb.ProjectPlug]

    get "/projects/:project_id", ProjectController, :show
    get "/projects/:project_id/edit", ProjectController, :edit
    put "/projects/:project_id/edit", ProjectController, :post_edit
    get "/projects/:project_id/delete", ProjectController, :delete
    put "/projects/:project_id/delete", ProjectController, :post_delete

    resources "/projects/:project_id/senders", SenderController
    get "/projects/:project_id/senders/:id/delete", SenderController, :delete_confirmation

    get "/projects/:project_id/contacts", ContactController, :index
    get "/projects/:project_id/contacts/new", ContactController, :new
    post "/projects/:project_id/contacts/new", ContactController, :post_new
    get "/projects/:project_id/contacts/import", ContactController, :import
    get "/projects/:project_id/contacts/:id", ContactController, :edit
    put "/projects/:project_id/contacts/:id", ContactController, :post_edit
    delete "/projects/:project_id/contacts", ContactController, :delete

    get "/projects/:project_id/forms", FormController, :index
    get "/projects/:project_id/forms/new", FormController, :new
    get "/projects/:project_id/forms/:id", FormController, :edit
    put "/projects/:project_id/forms/:id", FormController, :post_edit
    delete "/projects/:project_id/forms", FormController, :delete

    get "/projects/:project_id/templates", TemplateController, :index
    get "/projects/:project_id/templates/new", TemplateController, :new
    post "/projects/:project_id/templates/new", TemplateController, :post_new
    get "/projects/:project_id/templates/:id", TemplateController, :edit
    put "/projects/:project_id/templates/:id", TemplateController, :post_edit
    get "/projects/:project_id/templates/:id/clone", TemplateController, :clone
    post "/projects/:project_id/templates/:id/clone", TemplateController, :post_clone
    delete "/projects/:project_id/templates", TemplateController, :delete

    get "/projects/:project_id/segments", SegmentController, :index
    get "/projects/:project_id/segments/new", SegmentController, :new
    post "/projects/:project_id/segments", SegmentController, :create
    get "/projects/:project_id/segments/:id", SegmentController, :edit
    delete "/projects/:project_id/segments", SegmentController, :delete

    get "/projects/:project_id/campaigns", CampaignController, :index
    get "/projects/:project_id/campaigns/new", CampaignController, :new
    post "/projects/:project_id/campaigns/new", CampaignController, :post_new
    get "/projects/:project_id/campaigns/:id", CampaignController, :edit
    put "/projects/:project_id/campaigns/:id", CampaignController, :post_edit
    get "/projects/:project_id/campaigns/:id/stats", CampaignController, :stats
    get "/projects/:project_id/campaigns/:id/clone", CampaignController, :clone
    post "/projects/:project_id/campaigns/:id/clone", CampaignController, :post_clone
    delete "/projects/:project_id/campaigns", CampaignController, :delete
  end

  # Public Routes
  pipeline :browser_embeddable do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {KeilaWeb.FormLayoutView, :root}
    plug :put_layout, false
    plug :put_secure_browser_headers
    plug KeilaWeb.Meta.Plug
  end

  scope "/", KeilaWeb do
    pipe_through [:browser_embeddable]

    get "/forms/:id", FormController, :display
    post "/forms/:id", FormController, :submit
    get "/unsubscribe/:project_id/:contact_id", FormController, :unsubscribe
    post "/unsubscribe/:project_id/:contact_id", FormController, :unsubscribe

    get "/r/:encoded_url/:recipient_id/:hmac", TrackingController, :track_open
    get "/c/:encoded_url/:recipient_id/:link_id/:hmac", TrackingController, :track_click
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", KeilaWeb do
    pipe_through :api

    get "/campaigns", ApiController, :index_campaigns
    post "/campaigns", ApiController, :create_campaign
    get "/campaigns/:id", ApiController, :show_campaign
    patch "/campaigns/:id", ApiController, :update_campaign
    post "/campaigns/:id/send", ApiController, :send_campaign
    post "/campaigns/:id/schedule", ApiController, :schedule_campaign
    delete "/campaigns/:id", ApiController, :delete_campaign

    get "/contacts", ApiController, :index_contacts
    post "/contacts", ApiController, :create_contact
    get "/contacts/:id", ApiController, :show_contact
    patch "/contacts/:id", ApiController, :update_contact
    delete "/contacts/:id", ApiController, :delete_contact

    get "/segments", ApiController, :index_segment
    post "/segments", ApiController, :create_segment
    get "/segments/:id", ApiController, :show_segment
    patch "/segments/:id", ApiController, :update_segment
    delete "/segments/:id", ApiController, :delete_segment
  end

  # Webhooks
  scope "/api/webhooks", KeilaWeb do
    pipe_through :api

    post "/paddle", PaddleWebhookController, :webhook
    post "/senders/ses", SESWebhookController, :webhook
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: KeilaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview, base_path: "/dev/mailbox"
    end
  end
end
