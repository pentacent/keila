defmodule KeilaWeb.ApiMessageController do
  use KeilaWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Keila

  alias Keila.Mailings
  alias Keila.Mailings.Renderer
  alias KeilaWeb.Api.Schemas
  alias KeilaWeb.Api.Errors

  plug KeilaWeb.Api.Plugs.Authorization
  plug KeilaWeb.Api.Plugs.Normalization

  tags(["Transactional Messages"])

  operation(:create,
    summary: "Send a transactional message",
    description: """
    Sends a one-off transactional email.

    You can use an existing contact as the recipient by supplying the `contact_id`
    or `external_contact_id` field.

    Alternatively, you can specify `recipient_email` to send the message to a recipient
    who might not be in your contact list. If there is a matching contact in your project,
    the message will be linked to that contact and contact data will be available in the message.

    The message body must either come from the referenced template (via `template_id`) or
    be supplied in the request (e.g. `mjml_body`, `html_body`, or `text_body` depending on `type`).
    """,
    request_body:
      {"Transactional message params", "application/json",
       Schemas.TransactionalMessage.SendParams},
    responses: [
      ok: {"Message response", "application/json", Schemas.TransactionalMessage.Response}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _params) do
    case Mailings.send_transactional_message(project_id(conn), conn.body_params.data) do
      {:ok, message} ->
        render(conn, "message.json", %{message: message})

      {:error, %Ecto.Changeset{} = changeset} ->
        Errors.send_changeset_error(conn, changeset)

      {:error, reason} ->
        send_send_message_error(conn, reason)
    end
  end

  operation(:render,
    summary: "Render a transactional message",
    description: """
    Renders a transactional message without sending it and returns the
    rendered `subject`, `html_body`, and `text_body`.

    Takes the same parameters as the endpoint for sending a message.
    """,
    request_body:
      {"Transactional message params", "application/json",
       Schemas.TransactionalMessage.SendParams},
    responses: [
      ok:
        {"Renderer output", "application/json",
         Schemas.TransactionalMessage.RendererOutputResponse}
    ]
  )

  @spec render(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def render(conn, _params) do
    case Mailings.transactional_message_preview(project_id(conn), conn.body_params.data) do
      {:ok, %Renderer.Output{valid?: true} = output} ->
        render(conn, "renderer_output.json", %{output: output})

      {:ok, %Renderer.Output{valid?: false} = output} ->
        send_rendering_error(conn, output.errors)

      {:error, %Ecto.Changeset{} = changeset} ->
        Errors.send_changeset_error(conn, changeset)

      {:error, reason} ->
        send_send_message_error(conn, reason)
    end
  end

  defp send_send_message_error(conn, reason)
       when reason in [:sender_not_found, :template_not_found, :contact_not_found] do
    Errors.send_404(conn)
  end

  defp send_send_message_error(conn, :no_subject) do
    send_400(conn, "No subject")
  end

  defp send_send_message_error(conn, {:rendering_failed, errors}) do
    send_rendering_error(conn, errors)
  end

  defp send_send_message_error(conn, :insufficient_credits) do
    conn
    |> put_status(402)
    |> put_view(KeilaWeb.ApiErrorView)
    |> render("errors.json",
      errors: [[status: 402, title: "Insufficient credits"]]
    )
  end

  Keila.if_cloud do
    defp send_send_message_error(conn, :account_not_active) do
      conn
      |> put_status(403)
      |> put_view(KeilaWeb.ApiErrorView)
      |> render("errors.json",
        errors: [[status: 403, title: "Account not active"]]
      )
    end
  end

  defp send_rendering_error(conn, errors) do
    errors = if errors == [], do: ["Rendering failed"], else: errors

    conn
    |> put_status(400)
    |> put_view(KeilaWeb.ApiErrorView)
    |> render("errors.json",
      errors: Enum.map(errors, &[status: 400, title: "Rendering failed", detail: &1])
    )
  end

  defp send_400(conn, title) do
    conn
    |> put_status(400)
    |> put_view(KeilaWeb.ApiErrorView)
    |> render("errors.json",
      errors: [[status: 400, title: title |> to_string()]]
    )
  end

  defp project_id(conn), do: conn.assigns.current_project.id
end
