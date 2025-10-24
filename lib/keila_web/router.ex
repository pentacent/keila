defmodule KeilaWeb.Router do
  require Keila
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
    plug KeilaWeb.PutLocalePlug
    plug KeilaWeb.InstanceInfoPlug
  end

  # Non-authenticated Routes
  scope "/", KeilaWeb do
    pipe_through :browser

    get "/verify-sender/:token", SenderController, :verify_from_token
    get "/verify-sender/c/:token", SenderController, :cancel_verification_from_token
  end

  scope "/" do
    pipe_through :browser

    get "/api", KeilaWeb.ApiDocsController, :show
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
    
    # Two-factor authentication challenge for unauthenticated users
    get "/auth/2fa/challenge", TwoFactorController, :challenge
    post "/auth/2fa/verify", TwoFactorController, :verify
    post "/auth/2fa/resend", TwoFactorController, :resend_code
    
    # WebAuthn authentication for unauthenticated users
    post "/auth/webauthn/authenticate/begin", WebauthnController, :authenticate_begin
    post "/auth/webauthn/authenticate/complete", WebauthnController, :authenticate_complete
  end

  # Authenticated Routes without activation requirement
  pipeline :activation_not_required do
    plug KeilaWeb.AuthSession.RequireAuthPlug, allow_not_activated: true
  end

  scope "/", KeilaWeb do
    pipe_through [:browser, :activation_not_required]

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

    # Two-factor authentication management
    get "/auth/2fa/setup", TwoFactorController, :setup
    post "/auth/2fa/enable", TwoFactorController, :enable
    post "/auth/2fa/disable", TwoFactorController, :disable

    # WebAuthn management (authenticated users)
    post "/auth/webauthn/register/begin", WebauthnController, :register_begin
    post "/auth/webauthn/register/complete", WebauthnController, :register_complete
    delete "/auth/webauthn/credential/:credential_id", WebauthnController, :remove_credential

    Keila.if_cloud do
      get "/account/onboarding", CloudAccountController, :onboarding
    end

    get "/", ProjectController, :index
    get "/projects/new", ProjectController, :new
    post "/projects/new", ProjectController, :post_new

    get "/admin/users", UserAdminController, :index
    get "/admin/users/new", UserAdminController, :new
    post "/admin/users", UserAdminController, :create
    delete "/admin/users", UserAdminController, :delete
    get "/admin/users/:id/edit", UserAdminController, :edit
    put "/admin/users/:id", UserAdminController, :update
    post "/admin/users/:id/activate", UserAdminController, :activate
    post "/admin/users/:id/deactivate", UserAdminController, :deactivate
    post "/admin/users/:id/enable_2fa", UserAdminController, :enable_2fa
    post "/admin/users/:id/disable_2fa", UserAdminController, :disable_2fa
    delete "/admin/users/:id/webauthn", UserAdminController, :remove_webauthn_key
    post "/admin/users/:id/disable_all_webauthn", UserAdminController, :disable_all_webauthn
    post "/admin/users/:id/update_password", UserAdminController, :update_password
    post "/admin/users/:id/send_password_reset", UserAdminController, :send_password_reset
    get "/admin/users/:id/impersonate", UserAdminController, :impersonate
    get "/admin/users/:id/credits", UserAdminController, :show_credits
    post "/admin/users/:id/credits", UserAdminController, :create_credits

    Keila.if_cloud do
      get "/admin/users/:id/status", CloudAdminController, :show_user_account_status
      post "/admin/users/:id/status", CloudAdminController, :update_user_account_status
    end

    resources "/admin/shared-senders", SharedSenderAdminController
    get "/admin/shared-senders/:id/delete", SharedSenderAdminController, :delete_confirmation

    get "/admin/instance", InstanceAdminController, :show
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
    get "/projects/:project_id/contacts/unsubscribed", ContactController, :index_unsubscribed
    get "/projects/:project_id/contacts/unreachable", ContactController, :index_unreachable
    get "/projects/:project_id/contacts/new", ContactController, :new
    post "/projects/:project_id/contacts/new", ContactController, :post_new
    get "/projects/:project_id/contacts/import", ContactController, :import
    get "/projects/:project_id/contacts/export", ContactController, :export
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
    get "/projects/:project_id/segments/:id/contacts_export", SegmentController, :contacts_export
    delete "/projects/:project_id/segments", SegmentController, :delete

    get "/projects/:project_id/campaigns", CampaignController, :index
    get "/projects/:project_id/campaigns/new", CampaignController, :new
    post "/projects/:project_id/campaigns/new", CampaignController, :post_new
    get "/projects/:project_id/campaigns/:id", CampaignController, :edit
    get "/projects/:project_id/campaigns/:id/stats", CampaignController, :stats
    get "/projects/:project_id/campaigns/:id/view", CampaignController, :view
    get "/projects/:project_id/campaigns/:id/share", CampaignController, :share
    post "/projects/:project_id/campaigns/:id/share", CampaignController, :post_share
    get "/projects/:project_id/campaigns/:id/clone", CampaignController, :clone
    post "/projects/:project_id/campaigns/:id/clone", CampaignController, :post_clone
    delete "/projects/:project_id/campaigns", CampaignController, :delete

    resources "/projects/:project_id/api_keys", ApiKeyController,
      only: [:index, :create, :new, :delete]
  end

  # Public Routes
  pipeline :browser_embeddable do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {KeilaWeb.PublicFormLayoutView, :root}
    plug :put_layout, false
    plug :put_secure_browser_headers, %{"content-security-policy" => "frame-ancestors *"}
    plug KeilaWeb.Meta.Plug
    plug KeilaWeb.PutLocalePlug
  end

  scope "/", KeilaWeb do
    pipe_through [:browser_embeddable]

    get "/forms/:id", PublicFormController, :show
    post "/forms/:id", PublicFormController, :submit
    get "/unsubscribe/:project_id/:recipient_id/:hmac", PublicFormController, :unsubscribe
    post "/unsubscribe/:project_id/:recipient_id/:hmac", PublicFormController, :unsubscribe
    get "/double-opt-in/:form_id/:form_params_id/:hmac", PublicFormController, :double_opt_in

    get "/double-opt-in/:form_id/:form_params_id/:hmac/cancel",
        PublicFormController,
        :cancel_double_opt_in

    get "/r/:encoded_url/:recipient_id/:hmac", TrackingController, :track_open
    get "/c/:encoded_url/:recipient_id/:link_id/:hmac", TrackingController, :track_click

    get "/archive/:id", PublicCampaignController, :show

    # DEPRECATED: These routes will be removed in a future Keila release
    get "/unsubscribe/:project_id/:contact_id", PublicFormController, :unsubscribe
    post "/unsubscribe/:project_id/:contact_id", PublicFormController, :unsubscribe
  end

  scope "/uploads", KeilaWeb do
    pipe_through :browser

    get "/:filename", LocalFileController, :serve
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :open_api do
    plug OpenApiSpex.Plug.PutApiSpec, module: KeilaWeb.ApiSpec
  end

  scope "/api/v1" do
    pipe_through [:api, :open_api]
    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api/v1", KeilaWeb do
    pipe_through [:api, :open_api]

    resources "/contacts", ApiContactController, only: [:index, :show, :create, :update, :delete]
    patch "/contacts/:id/data", ApiContactController, :update_data
    post "/contacts/:id/data", ApiContactController, :replace_data

    resources "/campaigns", ApiCampaignController,
      only: [:index, :show, :create, :update, :delete]

    post "/campaigns/:id/actions/send", ApiCampaignController, :deliver
    post "/campaigns/:id/actions/schedule", ApiCampaignController, :schedule

    resources "/forms", ApiFormController, only: [:index, :show, :create, :update, :delete]
    post "/forms/:id/actions/submit", ApiFormController, :submit

    resources "/segments", ApiSegmentController, only: [:index, :show, :create, :update, :delete]

    resources "/senders", ApiSenderController, only: [:index]
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
