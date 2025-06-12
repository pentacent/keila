require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudAccountOnboardingLive do
    use KeilaWeb, :live_view
    import Ecto.Changeset

    alias KeilaCloud.Accounts.Account.ContactData
    alias KeilaCloud.Accounts.Account.OnboardingReviewData
    alias KeilaCloud.Countries

    @impl true
    def mount(_params, session, socket) do
      Gettext.put_locale(session["locale"])
      current_user = session["current_user"]
      current_account = session["current_account"]
      countries = Countries.country_options(session["locale"])

      {:ok,
       socket
       |> assign(:current_user, session["current_user"])
       |> assign(:current_account, session["current_account"])
       |> assign(:countries, countries)
       |> assign(:step, :user_name)
       |> put_user_changeset()
       |> put_contact_data_changeset()
       |> put_onboarding_review_data_changeset()}
    end

    defp put_user_changeset(socket, params \\ %{}) do
      assign(
        socket,
        :user_changeset,
        Keila.Auth.User.update_name_changeset(socket.assigns.current_user, params)
      )
    end

    @org_name_contact_fields ~w[is_organization organization_name website]a
    @address_contact_fields ~w[country address_line_1 locality]a
    defp required_contact_data_fields(:address), do: @address_contact_fields
    defp required_contact_data_fields(_), do: @org_name_contact_fields

    defp put_contact_data_changeset(socket, params \\ %{}) do
      required_fields = required_contact_data_fields(socket.assigns.step)
      contact_data = socket.assigns.current_account.contact_data || %ContactData{}

      assign(
        socket,
        :contact_data_changeset,
        ContactData.changeset(contact_data, params, required_fields)
      )
    end

    defp put_onboarding_review_data_changeset(socket, params \\ %{}) do
      onboarding_review_data =
        socket.assigns.current_account.onboarding_review_data ||
          %KeilaCloud.Accounts.Account.OnboardingReviewData{}

      assign(
        socket,
        :onboarding_review_data_changeset,
        KeilaCloud.Accounts.Account.OnboardingReviewData.changeset(onboarding_review_data, params)
      )
    end

    @impl true
    def render(assigns) do
      Phoenix.View.render(KeilaWeb.CloudAccountView, "onboarding.html", assigns)
    end

    @impl true
    def handle_event("update_user_name", %{"user" => params}, socket) do
      {:noreply,
       socket
       |> put_user_changeset(params)}
    end

    def handle_event("submit_user_name", %{"user" => user_params}, socket) do
      case Keila.Auth.update_user_name(socket.assigns.current_user.id, user_params) do
        {:ok, user} ->
          {:noreply,
           socket
           |> assign(:current_user, user)
           |> assign(:step, :org_name)
           |> put_user_changeset()}

        {:error, changeset} ->
          {:noreply, socket |> assign(:user_changeset, changeset)}
      end
    end

    @impl true
    def handle_event("update_org_name", %{"contact_data" => params}, socket) do
      {:noreply,
       socket
       |> put_contact_data_changeset(params)}
    end

    def handle_event("submit_org_name", %{"contact_data" => params}, socket) do
      case KeilaCloud.Accounts.update_account_contact_data(
             socket.assigns.current_account.id,
             params,
             required_contact_data_fields(:org_name)
           ) do
        {:ok, account} ->
          {:noreply,
           socket
           |> assign(:current_account, account)
           |> assign(:step, :address)
           |> put_contact_data_changeset()}

        {:error, changeset} ->
          {:noreply, socket |> assign(:contact_data_changeset, changeset.changes[:contact_data])}
      end
    end

    def handle_event("update_address", %{"contact_data" => params}, socket) do
      {:noreply,
       socket
       |> put_contact_data_changeset(params)}
    end

    def handle_event("submit_address", %{"contact_data" => params}, socket) do
      case KeilaCloud.Accounts.update_account_contact_data(
             socket.assigns.current_account.id,
             params,
             required_contact_data_fields(:address)
           ) do
        {:ok, account} ->
          {:noreply,
           socket
           |> assign(:current_account, account)
           |> assign(:step, :onboarding_review_data)
           |> put_contact_data_changeset()}

        {:error, changeset} ->
          {:noreply, socket |> assign(:contact_data_changeset, changeset.changes[:contact_data])}
      end
    end

    def handle_event(
          "update_onboarding_review_data",
          %{"onboarding_review_data" => params},
          socket
        ) do
      {:noreply, socket |> put_onboarding_review_data_changeset(params)}
    end

    def handle_event(
          "submit_onboarding_review_data",
          %{"onboarding_review_data" => params},
          socket
        ) do
      case KeilaCloud.Accounts.update_onboarding_review_data(
             socket.assigns.current_account.id,
             params
           ) do
        {:ok, account} ->
          if account.status in [:default, :onboarding_required] do
            {:ok, _account} = KeilaCloud.Accounts.update_account_status(account.id, :under_review)
          end

          {:noreply,
           socket
           |> assign(:current_account, account)
           |> assign(:step, :completed)
           |> put_onboarding_review_data_changeset()}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(
             :onboarding_review_data_changeset,
             changeset.changes[:onboarding_review_data]
           )}
      end
    end
  end
end
