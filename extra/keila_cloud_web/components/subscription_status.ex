require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Components.SubscriptionStatus do
    use Phoenix.Component
    use KeilaWeb.Gettext
    import Phoenix.HTML
    import KeilaWeb.IconHelper
    import KeilaWeb.DateTimeHelpers, only: [local_date_tag: 1]

    alias KeilaCloud.Billing
    alias KeilaWeb.Router.Helpers, as: Routes

    # attr :current_user, Keila.Auth.User, required: true
    # attr :account, Keila.Accounts.Account, required: true

    def subscription_status(assigns) do
      subscription = Billing.get_account_subscription(assigns.account.id)
      plan = if subscription, do: Billing.get_plan(subscription.paddle_plan_id)

      subscription_expiry_date =
        with %{next_billed_on: %Date{} = date} <- subscription,
             :gt <- Date.compare(date, Date.utc_today()) do
          date
        else
          _ -> nil
        end

      assigns =
        assigns
        |> assign(:subscription, subscription)
        |> assign(:plans, Billing.get_plans())
        |> assign(:plan, plan)
        |> assign(:subscription_expiry_date, subscription_expiry_date)

      ~H"""
      <div class="rounded shadow p-8 mt-8 max-w-5xl mx-auto flex flex-col gap-4 bg-gray-900 text-gray-50">
        <h2 class="text-3xl font-bold">
          {gettext("Subscription")}
        </h2>

        <%= if @subscription do %>
          <%= case @subscription.status do %>
            <% :active -> %>
              <p class="flex gap-4 items-center">
                <span class="flex h-2 w-8 items-center text-emerald-500">
                  {render_icon(:check)}
                </span>
                {gettext("You currently have an active subscription. Thanks for supporting Keila!")}
              </p>
            <% :paused -> %>
              <p class="flex gap-4 items-center">
                <span class="flex h-2 w-8 items-center text-red-500">
                  {render_icon(:information_circle)}
                </span>
                {gettext(
                  "Your subscription is currently suspended. Please update your payment method to continue using Keila."
                )}
              </p>
            <% :past_due -> %>
              <p class="flex gap-4 items-center">
                <span class="flex h-2 w-8 items-center text-red-500">
                  {render_icon(:information_circle)}
                </span>
                {gettext(
                  "There was an error processing your payment. Please update your payment method to continue using Keila."
                )}
              </p>
            <% :deleted -> %>
              <p class="flex gap-4 items-center">
                <span class="flex h-2 w-8 items-center text-red-500">
                  {render_icon(:information_circle)}
                </span>
                {gettext("Your subscription has been cancelled.")}
              </p>
              <%= if @subscription_expiry_date do %>
                <p class="text-gray-300">
                  {gettext("You can continue using your subscription until:")}
                  {local_date_tag(@subscription_expiry_date)}.
                </p>
              <% end %>
              <form
                method="post"
                action={Routes.cloud_account_path(KeilaWeb.Endpoint, :delete_subscription)}
              >
                <input type="hidden" name="_method" value="delete" />
                <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
                <button type="submit" class="button button--cta">
                  {gettext("Start new subscription")}
                </button>
              </form>
          <% end %>

          <%= if @subscription.status != :deleted do %>
            <div class="flex flex-row">
              <div class="text-center flex flex-col gap-4 items-center bg-gray-800 rounded">
                <.plan_card
                  plan={@plan}
                  account={@account}
                  current_user={@current_user}
                  subscription={@subscription}
                />
              </div>
            </div>
          <% end %>
        <% else %>
          {gettext("Subscribe now and start sending emails!")}

          <div x-data="{annual: false}" class="my-8">
            <label class="flex gap-2 cursor-pointer items-center justify-center">
              <input type="checkbox" class="hidden" x-model="annual" />
              <div
                class="relative h-6 w-11 rounded-full transition-colors"
                x-bind:class="{ 'bg-gray-300': !annual, 'bg-emerald-600': annual }"
              >
                <span
                  class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white transition-transform"
                  x-bind:class="{ 'translate-x-full': annual }"
                >
                </span>
              </div>
              <span>{dgettext("cloud", "Subscribe for a year and get one month for free!")}</span>
            </label>

            <div x-show="annual" class="grid grid-cols-2 md:grid-cols-3 gap-8">
              <%= for plan <- @plans, plan.billing_interval == :year do %>
                <.plan_card plan={plan} account={@account} current_user={@current_user} />
              <% end %>
            </div>

            <div x-show="!annual" class="grid grid-cols-2 md:grid-cols-3 gap-8">
              <%= for plan <- @plans, plan.billing_interval == :month do %>
                <.plan_card plan={plan} account={@account} current_user={@current_user} />
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <script src="https://cdn.paddle.com/paddle/paddle.js">
      </script>
      <script>
        window.addEventListener('DOMContentLoaded', function() {
            Paddle.Environment.set('<%= Application.get_env(:keila, KeilaCloud.Billing) |> Keyword.fetch!(:paddle_environment) %>')
            Paddle.Setup({
            vendor: <%= Application.get_env(:keila, KeilaCloud.Billing) |> Keyword.fetch!(:paddle_vendor) %>
            })

            const products = new Set()
            const elements = document.querySelectorAll('[data-product]')
            elements.forEach(element => {
            products.add(element.dataset.product)
            })

            const annualToMonthly = (price) => {
            const prefixMatch = price.match(/^([^\d.]+)/)
            const prefix = prefixMatch ? prefixMatch[1] : ''
            const suffixMatch = price.match(/([^\d.]+)$/)
            const suffix = suffixMatch ? suffixMatch[1] : ''

            const number = price.replace(prefix, '').replace(suffix, '')
            const amount = parseFloat(number)

            const monthlyAmount = (amount / 12).toFixed(2)

            return prefix + monthlyAmount + suffix
            }

            products.forEach(product => {

            Paddle.Product.Prices(product, 1, (result) => {
                document.querySelectorAll(`.price[data-product="${product}"]`).forEach(element => {
                const price = element.classList.contains("price-gross") ? result.price.gross : result.price.net

                if (element.classList.contains("price-year")) {
                    element.textContent = annualToMonthly(price)
                } else {
                    element.textContent = price
                }
                })
                console.log(result)
            })
            })

        });
      </script>
      """
    end

    defp plan_card(assigns) do
      ~H"""
      <div class="p-4 text-center flex flex-col gap-4 items-center rounded-sm">
        <h3>
          <span class="text-2xl font-bold">
            {@plan.name}
          </span>

          <%= if @plan.billing_interval == :year do %>
            <span class="block text-xs -mt-1 mb-2">
              {gettext("billed annually")}
            </span>
          <% end %>

          <%= if @plan.billing_interval == :one_time do %>
            <span class="block -mt-1 text-sm text-emerald-100 font-bold">
              {raw(
                gettext("%{price} one time",
                  price:
                    ~s{<span class="price price-net price-#{@plan.billing_interval}" data-product="#{@plan.paddle_id}"></span>}
                )
              )}
            </span>
          <% else %>
            <span class="block -mt-1 text-sm text-emerald-100 font-bold">
              {raw(
                gettext("%{price} / month",
                  price:
                    ~s{<span class="price price-net price-#{@plan.billing_interval}" data-product="#{@plan.paddle_id}"></span>}
                )
              )}
            </span>
          <% end %>
          <span class="block text-xs text-emerald-300">
            {raw(
              gettext("(%{price} incl. tax)",
                price:
                  ~s{<span class="price price-gross price-#{@plan.billing_interval}" data-product="#{@plan.paddle_id}"></span>}
              )
            )}
          </span>
        </h3>
        <ul>
          <%= if @plan.billing_interval == :one_time do %>
            <li class="flex items-center gap-1">
              <span class="inline-flex w-4 h-4">{render_icon(:check)}</span>
              {gettext("%{monthly_emails} emails",
                monthly_emails: @plan.monthly_credits
              )}
            </li>
            <li class="flex items-center gap-1">
              <span class="inline-flex w-4 h-4">{render_icon(:check)}</span>
              {gettext("valid for one year")}
            </li>
            <li class="flex items-center gap-1">
              <span class="inline-flex w-4 h-4">{render_icon(:check)}</span>
              {gettext("no subscription")}
            </li>
          <% else %>
            <li class="flex items-center gap-1">
              <span class="inline-flex w-4 h-4">{render_icon(:check)}</span>

              {gettext("%{monthly_emails} emails/month",
                monthly_emails: @plan.monthly_credits
              )}
            </li>
          <% end %>
          <li class="flex items-center gap-1">
            <span class="inline-flex w-4 h-4">{render_icon(:check)}</span>
            {gettext("unlimited contacts")}
          </li>
        </ul>
        <%= if assigns[:subscription] && @subscription.paddle_plan_id == @plan.paddle_id do %>
          <div class="flex gap-4">
            <%= if @subscription.update_url do %>
              <a class="button" target="_blank" href={@subscription.update_url}>
                {gettext("Update payment method")}
              </a>
            <% end %>
            <%= if @subscription.cancel_url do %>
              <a class="button" target="_blank" href={@subscription.cancel_url}>
                {gettext("Cancel subscription")}
              </a>
            <% end %>
          </div>
        <% else %>
          <button
            class="paddle_button button button--large button--cta w-full block justify-center"
            data-product={@plan.paddle_id}
            data-email={@current_user.email}
            data-passthrough={Jason.encode!(%{"account_id" => @account.id})}
            data-theme="none"
            data-success={Routes.cloud_account_url(KeilaWeb.Endpoint, :await_subscription)}
          >
            {gettext("Get started")}
          </button>
        <% end %>
      </div>
      """
    end
  end
end
