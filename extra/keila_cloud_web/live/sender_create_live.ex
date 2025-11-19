require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudSenderCreateLive.SetupData do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :name, :string
      field :email, :string
      field :use_swk, :boolean
      field :adapter_type, :string
      embeds_one :adapter_config, Keila.Mailings.Sender.Config
    end

    def changeset(data \\ %__MODULE__{}, params) do
      data
      |> cast(params, [:name, :email, :use_swk, :adapter_type])
      |> then(fn changeset ->
        use_swk? = get_field(changeset, :use_swk)

        adapter_type =
          if use_swk?, do: "send_with_keila", else: get_field(changeset, :adapter_type)

        adapter_config = get_field(changeset, :adapter_config)

        if !use_swk? && adapter_type && adapter_config do
          adapter_config =
            adapter_config |> change() |> put_change(:type, adapter_type)

          changeset
          |> put_change(:adapter_config, adapter_config)
          |> cast_embed(:adapter_config)
        else
          changeset
        end
      end)
    end
  end

  defmodule KeilaWeb.CloudSenderCreateLive do
    use KeilaWeb, :live_view
    use Keila.Repo
    import Ecto.Changeset
    alias Keila.Mailings.Sender

    @email_regex ~r/^[^\s@]+@[^\s@]+$/

    @steps [
      :use_swk,
      :name,
      :email,
      {:custom, :custom_adapter_type},
      {:custom, :custom_settings}
    ]

    defp next_step(step, data) do
      swk? = if data, do: data.use_swk, else: true

      steps =
        @steps
        |> Enum.filter(fn
          step when is_atom(step) -> true
          {:swk, _step} -> swk?
          {:custom, _step} -> !swk?
        end)
        |> Enum.map(fn
          step when is_atom(step) -> step
          {_type, step} -> step
        end)

      current_index = Enum.find_index(steps, &(&1 == step))

      if current_index < length(steps) - 1 do
        Enum.at(steps, current_index + 1)
      else
        :completed
      end
    end

    defp handle_step_submission(changeset, socket)

    defp handle_step_submission(changeset, _socket) do
      apply_action(changeset, :insert)
    end

    defp go_to_next_step(socket, data) do
      case next_step(socket.assigns.step, data) do
        :completed ->
          project_id = socket.assigns.current_project.id

          case create_sender(project_id, data) do
            {:ok, _sender} ->
              path = Routes.sender_path(socket, :index, project_id)
              redirect(socket, to: path)

            {:action_required, sender} ->
              path = Routes.sender_path(socket, :edit, project_id, sender.id)
              redirect(socket, to: path)

            {:error, _changeset} ->
              socket
          end

        step ->
          data = data || socket.assigns.setup_changeset
          changeset = setup_changeset(step, data)

          socket
          |> assign(:step, step)
          |> assign(:setup_changeset, changeset)
      end
    end

    defp create_sender(project_id, data) do
      Keila.Mailings.create_sender(project_id, %{
        name: data.name,
        from_name: data.name,
        from_email: data.email,
        config:
          if(data.use_swk,
            do: %{type: "send_with_keila"},
            else: data.adapter_config |> Map.from_struct()
          )
      })
    end

    defp setup_changeset(step, data, params \\ %{}) do
      required_fields =
        case step do
          :name -> [:name]
          :email -> [:email]
          :use_swk -> [:use_swk]
          :custom_type -> [:custom_adapter_type]
          _other -> []
        end

      __MODULE__.SetupData.changeset(data, params)
      |> validate_required(required_fields)
      |> validate_format(:email, @email_regex, message: "must have the @ sign and no spaces")
      |> validate_length(:email, max: 255)
      |> then(fn changeset ->
        if :email in required_fields, do: unsafe_validate_unique_email(changeset), else: changeset
      end)
      |> then(fn changeset ->
        if :name in required_fields, do: unsafe_validate_unique_name(changeset), else: changeset
      end)
    end

    # TODO: Change sender emails to Citext

    defp unsafe_validate_unique_name(changeset = %{valid?: true}) do
      name = get_field(changeset, :name)

      if Repo.exists?(from s in Sender, where: s.name == ^name) do
        add_error(changeset, :name, "already in use")
      else
        changeset
      end
    end

    defp unsafe_validate_unique_name(changeset = %{valid?: false}), do: changeset

    defp unsafe_validate_unique_email(changeset = %{valid?: true}) do
      email = get_field(changeset, :email)

      if Repo.exists?(from s in Sender, where: s.from_email == ^email) do
        add_error(changeset, :email, "already in use")
      else
        changeset
      end
    end

    defp unsafe_validate_unique_email(changeset = %{valid?: false}), do: changeset

    defp put_setup_changeset(socket, params \\ %{}) do
      data =
        if socket.assigns[:setup_changeset] do
          socket.assigns.setup_changeset
        else
          %__MODULE__.SetupData{
            name: socket.assigns.current_project.name,
            email: socket.assigns.current_user.email,
            adapter_config: %Keila.Mailings.Sender.Config{}
          }
        end

      changeset = setup_changeset(socket.assigns.step, data, params)
      assign(socket, :setup_changeset, changeset)
    end

    @impl true
    def mount(_params, session, socket) do
      current_project = Keila.Projects.get_project(session["current_project_id"])
      current_user = Keila.Auth.get_user(session["current_user_id"])

      {:ok,
       socket
       |> assign(:current_project, current_project)
       |> assign(:current_user, current_user)
       |> assign(:step, hd(@steps))
       |> put_setup_changeset()}
    end

    @impl true
    def render(assigns) do
      Phoenix.View.render(KeilaWeb.CloudSenderView, "create_live.html", assigns)
    end

    @impl true
    def handle_event("update_changeset", %{"sender" => params}, socket) do
      {:noreply, put_setup_changeset(socket, params)}
    end

    def handle_event("submit_step", %{"sender" => params}, socket) do
      setup_changeset(socket.assigns.step, socket.assigns.setup_changeset.data, params)
      |> handle_step_submission(socket)
      |> case do
        {:ok, data} ->
          {:noreply, go_to_next_step(socket, data)}

        {:error, changeset} ->
          {:noreply, socket |> assign(:setup_changeset, changeset)}
      end
    end
  end
end
