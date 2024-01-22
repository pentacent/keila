defmodule KeilaWeb.FormEditLive do
  use KeilaWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])
    current_project = session["current_project"]
    senders = Keila.Mailings.get_project_senders(current_project.id)
    templates = Keila.Templates.get_project_templates(current_project.id)

    socket =
      socket
      |> assign(:form, session["form"])
      |> assign(:changeset, Ecto.Changeset.change(session["form"]))
      |> assign(:current_project, current_project)
      |> assign(:senders, senders)
      |> assign(:templates, templates)
      |> assign(:double_opt_in_available, session["double_opt_in_available"])
      |> put_default_assigns()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.FormView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("form_updated", params, socket) do
    changeset =
      Keila.Contacts.Form.update_changeset(socket.assigns.form, params["form"])
      |> then(fn
        changeset = %{valid?: true} ->
          changeset

        changeset ->
          Ecto.Changeset.apply_action(changeset, :update) |> elem(1)
      end)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> put_default_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_custom_field", _params, socket) do
    socket =
      update(socket, :changeset, fn changeset ->
        existing = Ecto.Changeset.get_field(changeset, :field_settings, [])

        new = %Keila.Contacts.Form.FieldSettings{
          id: Ecto.UUID.generate(),
          field: :data,
          key: "foo",
          label: "Test",
          cast: true,
          type: :enum
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
                value: "foo",
                label: "Bar"
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

        socket
        |> assign(:form_preview, form)
        |> assign(:embed, embed)

      _other ->
        socket
    end
  end
end
