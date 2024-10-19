defmodule Keila.Auth.Emails do
  import Swoosh.Email
  # FIXME Don't depend on Web App here
  import KeilaWeb.Gettext

  @spec send!(atom(), map()) :: term() | no_return()
  def send!(email, params) do
    config = Application.get_env(:keila, __MODULE__, [])

    email
    |> build(params)
    |> Keila.Mailer.deliver!(config)
  end

  @spec build(:activate, %{url: String.t(), user: Keila.Auth.User.t()}) :: term() | no_return()
  def build(:activate, %{user: user, url: url}) do
    new()
    |> from({"Keila", system_from_email()})
    |> subject(dgettext("auth", "Please Verify Your Account"))
    |> to(user.email)
    |> text_body(
      dgettext(
        "auth",
        """
        Welcome to Keila,

        please confirm your new account by visiting the following link:

        %{url}

        If you weren’t trying to create an account, simply ignore this message.
        """,
        url: url
      )
    )
  end

  @spec build(:update_email, %{url: String.t(), user: Keila.Auth.User.t()}) ::
          term() | no_return()
  def build(:update_email, %{user: user, url: url}) do
    new()
    |> from({"Keila", system_from_email()})
    |> subject(dgettext("auth", "Please Verify Your Email"))
    |> to(user.email)
    |> text_body(
      dgettext(
        "auth",
        """
        Hey there,

        please confirm your new email address by visiting the following link:

        %{url}

        If you weren’t trying to change your email address, simply ignore this message.
        """,
        url: url
      )
    )
  end

  @spec build(:password_reset_link, %{url: String.t(), user: Keila.Auth.User.t()}) ::
          term() | no_return()
  def build(:password_reset_link, %{user: user, url: url}) do
    new()
    |> subject(dgettext("auth", "Your Account Reset Link"))
    |> to(user.email)
    |> from({"Keila", system_from_email()})
    |> text_body(
      dgettext(
        "auth",
        """
        Hey there,

        you have requested a password reset for your Keila account.

        You can set a new password by visiting the following link:

        %{url}

        If you weren’t trying to reset your password, simply ignore this message.
        """,
        url: url
      )
    )
  end

  @spec build(:login_link, %{url: String.t(), user: Keila.Auth.User.t()}) :: term() | no_return()
  def build(:login_link, %{user: user, url: url}) do
    new()
    |> subject(dgettext("auth", "Your Login Link"))
    |> to(user.email)
    |> from({"Keila", system_from_email()})
    |> text_body(
      dgettext(
        "auth",
        """
        Hey there,

        you can login to Keila with the following link:

        %{url}

        If you haven’t requested a login, simply ignore this message.
        """,
        url: url
      )
    )
  end

  defp system_from_email() do
    Application.get_env(:keila, __MODULE__) |> Keyword.fetch!(:from_email)
  end
end
