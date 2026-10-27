defmodule KeilaWeb.FormEditLive do
  use KeilaWeb, :live_view

  alias Keila.Contacts.Form
  alias Keila.Mailings.DoubleOptInMessage
  alias Keila.Mailings.WelcomeMessage

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])
    current_project = session["current_project"]
    senders = Keila.Mailings.get_project_senders(current_project.id)
    templates = Keila.Templates.get_project_templates(current_project.id)
    form = session["form"]

    socket =
      socket
      |> assign(:form, form)
      |> assign(:changeset, Ecto.Changeset.change(form))
      |> assign(:current_project, current_project)
      |> assign(:senders, senders)
      |> assign(:templates, templates)
      |> assign(:double_opt_in_available, session["double_opt_in_available"])
      |> assign(:welcome_email_available, session["welcome_email_available"])
      |> assign(:current_tab, "settings")
      |> assign(:email_params, %{})
      |> put_default_assigns()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.FormView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("form_updated", params, socket) do
    params =
      params["form"]
      |> put_new_field_defaults()
      |> put_new_allowed_value_defaults()
      |> merge_email_params(socket)

    changeset = Form.update_changeset(socket.assigns.form, params)

    {:noreply, put_form_changeset(socket, changeset)}
  end

  def handle_event("save", params, socket) do
    params = params["form"] |> merge_email_params(socket)

    case Keila.Contacts.update_form(socket.assigns.form.id, params) do
      {:ok, _form} ->
        {:noreply,
         redirect(socket, to: Routes.form_path(socket, :index, socket.assigns.current_project.id))}

      {:error, changeset} ->
        {:noreply, socket |> assign(:changeset, changeset) |> put_default_assigns()}
    end
  end

  def handle_event("reset_email", %{"email" => name}, socket) do
    params =
      Form.new_email()
      |> Map.from_struct()
      |> Map.update!(:editor_config, &Map.from_struct/1)
      |> Map.new(fn {key, value} -> {to_string(key), value} end)

    {:noreply, put_email_params(socket, name, params)}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(:current_tab, tab) |> put_default_assigns()}
  end

  @impl true
  def handle_info({:email_dialog, name, params}, socket) do
    params = Map.merge(Map.get(socket.assigns.email_params, name, %{}), params)
    {:noreply, put_email_params(socket, name, params)}
  end

  # Stores email params, then updates form changeset with them.
  # Email params are stored separately because they don't come
  # from an input in the form and need to be re-merged with the
  # form params when updating the changeset.
  defp put_email_params(socket, name, params) do
    changeset = Form.update_changeset(socket.assigns.changeset, %{name => params})

    socket
    |> update(:email_params, &Map.put(&1, name, params))
    |> put_form_changeset(changeset)
  end

  defp merge_email_params(params, socket) do
    Map.merge(params, socket.assigns.email_params)
  end

  defp put_new_field_defaults(params) do
    maybe_put_new_defaults(params, "field_settings", "field_settings_sort", %{
      "field" => "data",
      "key" => next_custom_field_key(params),
      "label" => gettext("Custom Field"),
      "cast" => "true",
      "type" => "string"
    })
  end

  defp next_custom_field_key(params) do
    highest =
      params
      |> Map.get("field_settings", %{})
      |> Map.values()
      |> Enum.map(&custom_field_number/1)
      |> Enum.max(fn -> 0 end)

    "custom_field_#{highest + 1}"
  end

  defp custom_field_number(%{"key" => "custom_field_" <> suffix}) do
    case Integer.parse(suffix) do
      {number, ""} -> number
      _other -> 0
    end
  end

  defp custom_field_number(_field_params), do: 0

  defp put_new_allowed_value_defaults(params = %{"field_settings" => field_settings}) do
    field_settings =
      Map.new(field_settings, fn {index, field_params} ->
        field_params =
          maybe_put_new_defaults(field_params, "allowed_values", "allowed_values_sort", %{
            "value" => "option-1",
            "label" => gettext("My Custom Option")
          })

        {index, field_params}
      end)

    Map.put(params, "field_settings", field_settings)
  end

  defp put_new_allowed_value_defaults(params), do: params

  # "Add" buttons append "new" to the sort param of an embed. Ecto then adds a new
  # entry and casts it with the params at the "new" index, which are set here.
  defp maybe_put_new_defaults(params, key, sort_key, defaults) do
    if "new" in Map.get(params, sort_key, []) do
      put_in(params, [Access.key(key, %{}), "new"], defaults)
    else
      params
    end
  end

  defp put_form_changeset(socket, changeset) do
    changeset =
      if changeset.valid?,
        do: changeset,
        else: Ecto.Changeset.apply_action(changeset, :update) |> elem(1)

    socket
    |> assign(:changeset, changeset)
    |> put_default_assigns()
  end

  defp put_default_assigns(socket) do
    case Ecto.Changeset.apply_action(socket.assigns.changeset, :update) do
      {:ok, form} ->
        embed =
          KeilaWeb.PublicFormView.render("show.html", %{
            form: form,
            mode: :embed,
            changeset: Keila.Contacts.Contact.changeset_from_form(%{}, form)
          })
          |> Phoenix.HTML.Safe.to_iodata()
          |> Floki.parse_fragment!()
          |> Floki.raw_html(pretty: true)

        double_opt_in_preview =
          if form.settings.double_opt_in_required &&
               socket.assigns.current_tab == "double-opt-in",
             do: DoubleOptInMessage.preview(form).html_body

        welcome_email_preview =
          if form.settings.welcome_enabled && socket.assigns.current_tab == "welcome-email",
            do: WelcomeMessage.preview(form).html_body

        socket
        |> assign(:form_preview, form)
        |> assign(:embed, embed)
        |> assign(:welcome_email_preview, welcome_email_preview)
        |> assign(:double_opt_in_preview, double_opt_in_preview)

      _other ->
        socket
    end
  end
end
