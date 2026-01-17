require Keila

Keila.if_cloud do
  defmodule KeilaCloudWeb.Components.SharedSendWithKeilaStatus do
    use Phoenix.LiveComponent
    use KeilaWeb.Gettext
    import KeilaWeb.IconHelper
    import KeilaWeb.DateTimeHelpers
    alias KeilaCloud.Mailings.SendWithKeila

    def mount(socket) do
      {:ok, assign(socket, :loading_sender_hash, nil)}
    end

    def update(assigns, socket) do
      {:ok, assign(socket, assigns) |> assign(:sender_hash, :erlang.phash2(assigns[:sender]))}
    end

    def render(assigns) do
      ~H"""
      <div id={"sender-status-#{@id}"} class="flex flex flex-col gap-2">
        <%= cond do %>
          <% @sender.config.swk_domain_is_known_shared_domain -> %>
            <div class="prose prose-sm prose-invert text-white px-2 rounded">
              <div class="max-w-md flex gap-2 items-center bg-gray-900 rounded p-2 -mx-2">
                <div class="w-6 h-6 flex">
                  {render_icon(:check)}
                </div>
                <div class="text-md">
                  {dgettext_md(
                    "cloud",
                    "You’re using a shared domain. Emails will be sent from *%{fallback_email}*. Replies will go to *%{from_email}*. [Read more](https://www.keila.io/docs/shared-domains){:target=\"_blank\"}",
                    fallback_email: KeilaCloud.Mailings.SendWithKeila.fallback_from_email(@sender),
                    from_email: @sender.from_email
                  )}
                </div>
              </div>
            </div>
          <% not is_nil(@sender.config.swk_domain) && is_nil(@sender.config.swk_domain_verified_at) -> %>
            <div class="px-4 rounded">
              <div class="flex gap-4 items-center prose prose-invert">
                <div class="w-8 h-8 flex animate-spin" style="animation-duration: 4000ms;">
                  {render_icon(:spinner)}
                </div>

                <div class="max-w-lg">
                  <h3 class="text-xl mt-4">
                    {dgettext("cloud", "Waiting for domain verification ...")}
                  </h3>
                  {dgettext_md(
                    "cloud",
                    "To ensure good deliverability of your emails, you need to verify your domain by adding DNS records. [Read more](https://www.keila.io/docs/managed-dmarc){:target=\"_blank\"}"
                  )}

                  <div class="text-sm">
                    {dgettext_md(
                      "cloud",
                      "Until you have verified your domain, emails for this sender will be sent from *%{fallback_email}*. Replies will go to *%{from_email}*.",
                      fallback_email: KeilaCloud.Mailings.SendWithKeila.fallback_from_email(@sender),
                      from_email: @sender.from_email
                    )}
                  </div>
                </div>
              </div>
              {render_dns_table(assigns)}
            </div>
          <% not is_nil(@sender.config.swk_domain_verified_at) -> %>
            <div class="prose prose-invert text-white px-2 rounded">
              <div class="max-w-md flex gap-2 items-center bg-emerald-900 rounded p-2 -mx-2">
                <div class="w-6 h-6 flex">
                  {render_icon(:check)}
                </div>
                <div class="text-md">
                  {dgettext("cloud", "Domain verified")}
                </div>
              </div>
            </div>
            <div class="-ml-2 -mt-1 -mb-4 text-sm">
              {render_dns_table(assigns)}
            </div>
          <% true -> %>
        <% end %>

        <%= if @sender.config.swk_domain_verified_at && is_nil(@sender.config.swk_mx2_set_up_at) do %>
          <div class="px-4 rounded">
            <div class="flex gap-4 items-center prose prose-invert">
              <div class="w-8 h-8 flex animate-spin" style="animation-duration: 4000ms;">
                {render_icon(:spinner)}
              </div>

              <div class="max-w-sm">
                <h3 class="text-xl mt-4">
                  {dgettext("cloud", "Finalizing your sender ...")}
                </h3>
                <p>
                  {dgettext(
                    "cloud",
                    "We're currently finalizing the setup of your sender. This may take a few minutes."
                  )}
                </p>
                <button
                  phx-click="check_domain"
                  phx-target={@myself}
                  type="button"
                  class="button transition disabled:cursor-wait"
                  disabled={@loading_sender_hash && @sender_hash == @loading_sender_hash}
                >
                  <%= if @loading_sender_hash && @sender_hash == @loading_sender_hash do %>
                    <div class="w-4 h-4 flex animate-spin" style="animation-duration: 8000ms;">
                      {render_icon(:spinner)}
                    </div>
                  <% end %>
                  {dgettext("cloud", "Check status")}
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @sender.config.swk_is_legacy do %>
          <div class="max-w-md prose prose-invert p-4 bg-amber-900 rounded">
            <div class="flex gap-2 items-center mb-3">
              <div class="w-6 h-6 flex">
                {render_icon(:exclamation_triangle)}
              </div>
              <div class="font-semibold">
                {dgettext("cloud", "Legacy Settings")}
              </div>
            </div>
            <p class="text-sm mb-4">
              {dgettext(
                "cloud",
                "You are currently using legacy email settings. We recommend updating to the new settings for better performance and reliability."
              )}
            </p>
            <button
              phx-click="reset_legacy_settings"
              phx-target={@myself}
              type="button"
              class="button button-primary transition disabled:cursor-wait"
              disabled={@loading_sender_hash && @sender_hash == @loading_sender_hash}
            >
              <%= if @loading_sender_hash && @sender_hash == @loading_sender_hash do %>
                <div class="w-4 h-4 flex animate-spin mr-2" style="animation-duration: 8000ms;">
                  {render_icon(:spinner)}
                </div>
              <% end %>
              {dgettext("cloud", "Update to new settings")}
            </button>
          </div>
        <% end %>
      </div>
      """
    end

    @entries [:mx1, :mx2, :dkim1, :dkim2, :dmarc]
    defp render_dns_table(assigns) do
      sender = assigns.sender

      entry_values =
        for entry <- @entries do
          value =
            case entry do
              :mx1 -> sender.config.swk_mx1_value
              :mx2 -> sender.config.swk_mx2_value
              :dkim1 -> sender.config.swk_dkim1_value
              :dkim2 -> sender.config.swk_dkim2_value
              :dmarc -> sender.config.swk_dmarc_value
            end

          {entry, value}
        end

      valid_entries =
        for {entry, value} <- entry_values do
          {entry, SendWithKeila.entry_valid?(sender, entry, value)}
        end

      subdomains =
        for entry <- @entries do
          {entry, SendWithKeila.subdomain(sender, entry)}
        end

      entry_types =
        for entry <- @entries do
          {entry, SendWithKeila.entry_type(entry)}
        end

      expected_values =
        for entry <- @entries do
          {entry, SendWithKeila.expected_value(sender, entry)}
        end

      assigns =
        assigns
        |> assign(:entry_values, entry_values)
        |> assign(:valid_entries, valid_entries)
        |> assign(:subdomains, subdomains)
        |> assign(:entry_types, entry_types)
        |> assign(:expected_values, expected_values)

      ~H"""
      <details class="mb-4">
        <summary class="pl-12 cursor-pointer hover:underline">
          {dgettext("cloud", "Show DNS Records")}
        </summary>

        <table class="border border-gray-600 mt-4">
          <thead>
            <tr class="text-left bg-gray-700">
              <th class="p-2 ">{dgettext("cloud", "Subdomain")}</th>
              <th class="p-2">{dgettext("cloud", "Type")}</th>
              <th colspan="2">{dgettext("cloud", "Value")}</th>
            </tr>
          </thead>
          <tbody>
            <%= for {entry, value} <- @entry_values, not is_nil(@expected_values[entry]) do %>
              <tr class="border-b border-gray-600">
                <td class="p-2">
                  <input
                    type="text"
                    class="p-0 border-0 bg-transparent text-sm w-auto min-w-0"
                    readonly
                    value={@subdomains[entry]}
                    x-data="{}"
                    x-on:click="$el.select()"
                  /><br />
                  <span class="text-xs text-gray-400">
                    ({@subdomains[entry]}.{@sender.config.swk_domain})
                  </span>
                </td>
                <td class="p-2">{@entry_types[entry] |> to_string() |> String.upcase()}</td>

                <%= if @valid_entries[entry] do %>
                  <td class="p-2" colspan="2">
                    <div class="flex gap-2 items-center">
                      <span class="w-4 h-4 shrink-0 text-emerald-600">
                        {render_icon(:check)}
                      </span>
                      <input
                        type="text"
                        class="p-0 border-0 bg-transparent text-sm w-auto min-w-0"
                        readonly
                        value={value}
                        x-data="{}"
                        x-on:click="$el.select()"
                      />
                    </div>
                  </td>
                <% else %>
                  <td class="p-2">
                    <input
                      type="text"
                      class="p-0 border-0 bg-transparent text-sm w-auto min-w-0"
                      readonly
                      value={@expected_values[entry]}
                      x-data="{}"
                      x-on:click="$el.select()"
                    />
                  </td>
                  <td class="p-2" colspan="2">
                    <div class="flex gap-2 items-center">
                      <span class="h-4 w-4 inline-flex text-amber-600">
                        {render_icon(:exclamation_triangle)}
                      </span>

                      <%= if is_nil(value) do %>
                        <span class="italic text-xs">{dgettext("cloud", "empty")}</span>
                      <% else %>
                        <div class="text-xs">
                          <span class="italic">{dgettext("cloud", "current value:")}</span>
                          <br />
                          <span>
                            {value}
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>

        <div class="flex flex-row items-center align-items-start gap-4 mt-4">
          <button
            phx-click="check_domain"
            phx-target={@myself}
            type="button"
            class="button transition disabled:cursor-wait"
            disabled={@loading_sender_hash && @sender_hash == @loading_sender_hash}
          >
            <%= if @loading_sender_hash && @sender_hash == @loading_sender_hash do %>
              <div class="w-4 h-4 flex animate-spin" style="animation-duration: 8000ms;">
                {render_icon(:spinner)}
              </div>
            <% end %>
            {dgettext("cloud", "Check Domain")}
          </button>

          <%= if @sender.config.swk_domain_checked_at && (!@loading_sender_hash || @sender_hash != @loading_sender_hash) do %>
            <div class="text-sm italic">
              {dgettext("cloud", "Last checked at:")}
              <span
                id="domain-checked-at"
                phx-hook="SetLocalDateTimeContent"
                data-value={@sender.config.swk_domain_checked_at |> maybe_print_datetime()}
                data-resolution="second"
                class="font-bold"
              >
              </span>
            </div>
          <% end %>
        </div>
      </details>
      """
    end

    def handle_event("check_domain", _, socket) do
      Task.start_link(fn ->
        :timer.sleep(500)
        SendWithKeila.verify_domain(socket.assigns.sender)
      end)

      {:noreply, assign(socket, :loading_sender_hash, :erlang.phash2(socket.assigns.sender))}
    end

    def handle_event("reset_legacy_settings", _, socket) do
      Task.start_link(fn ->
        :timer.sleep(500)

        SendWithKeila.reset_legacy_settings(socket.assigns.sender)
      end)

      {:noreply, assign(socket, :loading_sender_hash, :erlang.phash2(socket.assigns.sender))}
    end
  end
end
