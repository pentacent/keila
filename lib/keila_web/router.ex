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

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Unauthenticated Routes
  scope "/", KeilaWeb do
    pipe_through [:browser, KeilaWeb.AuthSession.RequireNoAuthPlug]

    get "/auth/login", AuthController, :login
    post "/auth/login", AuthController, :post_login
    get "/auth/register", AuthController, :register
    post "/auth/register", AuthController, :post_register
    get "/auth/activate", AuthController, :activate_required
    get "/auth/activate/:token", AuthController, :activate
    get "/auth/reset", AuthController, :reset
    post "/auth/reset", AuthController, :post_reset
    get "/auth/reset/:token", AuthController, :reset_change_password
    post "/auth/reset/:token", AuthController, :post_reset_change_password
  end

  # Authenticated Routes without a Project context
  scope "/", KeilaWeb do
    pipe_through [:browser, KeilaWeb.AuthSession.RequireAuthPlug]

    get "/", AuthController, :login
    get "/auth/logout", AuthController, :logout

    get "/", ProjectController, :index
    get "/projects/new", ProjectController, :new
    post "/projects/new", ProjectController, :post_new
  end

  # Authenticated Routes within a Project context
  scope "/", KeilaWeb do
    pipe_through [:browser, KeilaWeb.AuthSession.RequireAuthPlug, KeilaWeb.ProjectPlug]

    get "/projects/:project_id", ProjectController, :show
    get "/projects/:project_id/edit", ProjectController, :edit
    put "/projects/:project_id/edit", ProjectController, :post_edit
    get "/projects/:project_id/delete", ProjectController, :delete
    put "/projects/:project_id/delete", ProjectController, :post_delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", KeilaWeb do
  #   pipe_through :api
  # end

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
