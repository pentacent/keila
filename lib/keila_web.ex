defmodule KeilaWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use KeilaWeb, :controller
      use KeilaWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: KeilaWeb
      use KeilaWeb.Gettext

      import Plug.Conn
      import KeilaWeb.Meta, only: [put_meta: 3]
      import KeilaWeb.Captcha, only: [captcha_valid?: 1]
      import KeilaWeb.AuthSession, only: [start_auth_session: 2, end_auth_session: 1]

      alias KeilaWeb.Router.Helpers, as: Routes
      unquote(verified_routes())
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/keila_web/templates",
        namespace: KeilaWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      import KeilaWeb.Meta, only: [get_meta: 5]
      import KeilaWeb.Captcha, only: [captcha_tag: 0]

      # Include shared imports and aliases for views
      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {KeilaWeb.LayoutView, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp html_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers

      # Import LiveView and Component helpers (live_render, live_component, etc)
      import Phoenix.Component

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import KeilaWeb.ErrorHelpers
      import KeilaWeb.PaginationHelpers
      import KeilaWeb.DeleteButtonHelpers
      import KeilaWeb.IconHelper
      import KeilaWeb.DateTimeHelpers
      use KeilaWeb.Gettext

      alias KeilaWeb.Router.Helpers, as: Routes
      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: KeilaWeb.Endpoint,
        router: KeilaWeb.Router,
        statics: KeilaWeb.static_paths()
    end
  end

  def static_paths,
    do: ~w(css fonts images js social-icons favicon.ico robots.txt downloads api vendor)

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
