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
    params = params["form"] |> merge_email_params(socket)
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
  def handle_event("add_custom_field", _params, socket) do
    socket =
      update(socket, :changeset, fn changeset ->
        existing = Ecto.Changeset.get_field(changeset, :field_settings, [])

        new = %Keila.Contacts.Form.FieldSettings{
          id: Ecto.UUID.generate(),
          field: :data,
          key: "my_custom_field",
          label: gettext("My Custom Field"),
          cast: true,
          type: :string
        }

        Ecto.Changeset.put_embed(changeset, :field_settings, existing ++ [new])
      end)
      |> put_default_assigns()

    {:noreply, socket}
  end

  def handle_event("remove_custom_field", %{"fs-id" => fs_id}, socket) do
    socket =
      update(socket, :changeset, fn changeset ->
        field_settings =
          Ecto.Changeset.get_field(changeset, :field_settings, [])
          |> Enum.filter(&(&1.id != fs_id))

        Ecto.Changeset.put_embed(changeset, :field_settings, field_settings)
      end)
      |> put_default_assigns()

    {:noreply, socket}
  end

  def handle_event("add_allowed_value", %{"fs-id" => fs_id}, socket) do
    socket =
      update(socket, :changeset, fn changeset ->
        fields =
          Ecto.Changeset.get_field(changeset, :field_settings, [])
          |> Enum.map(fn field_setting ->
            if field_setting.id == fs_id do
              existing = field_setting.allowed_values || []

              new = %Keila.Contacts.Form.FieldSettings.AllowedValue{
                id: Ecto.UUID.generate(),
                value: "option-1",
                label: gettext("My Custom Option")
              }

              field_setting
              |> Ecto.Changeset.change()
              |> Ecto.Changeset.put_embed(:allowed_values, existing ++ [new])
            else
              field_setting
            end
          end)

        Ecto.Changeset.put_embed(changeset, :field_settings, fields)
      end)
      |> put_default_assigns()

    {:noreply, socket}
  end

  def handle_event("remove_allowed_value", %{"fs-id" => fs_id, "av-id" => av_id}, socket) do
    socket =
      update(socket, :changeset, fn changeset ->
        fields =
          Ecto.Changeset.get_field(changeset, :field_settings, [])
          |> Enum.map(fn field_setting ->
            if field_setting.id == fs_id do
              allowed_values =
                field_setting.allowed_values
                |> Enum.filter(fn allowed_value ->
                  allowed_value.id != av_id
                end)

              field_setting
              |> Ecto.Changeset.change()
              |> Ecto.Changeset.put_embed(:allowed_values, allowed_values)
            else
              field_setting
            end
          end)

        Ecto.Changeset.put_embed(changeset, :field_settings, fields)
      end)
      |> put_default_assigns()

    {:noreply, socket}
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
