require Keila

Keila.if_cloud do
  defmodule KeilaCloudWeb.Components.CloudRegistration do
    use Phoenix.Component
    use KeilaWeb.Gettext

    def cloud_registration(assigns) do
      ~H"""
      <div class="text-sm -mb-8 prose-a:underline">
        {dgettext_md(
          "cloud",
          "By creating an account, you agree to our [terms of service](%{tos_link}). Please also acknowledge our [privacy policy](%{pp_link}).",
          %{
            tos_link: "https://www.keila.io/legal/terms",
            pp_link: "https://www.keila.io/legal/privacy"
          }
        )}
      </div>

      <input type="hidden" name="account[ref]" id="account_ref" />
      <input type="hidden" name="account[utm_source]" id="account_utm_source" />
      <input type="hidden" name="account[utm_campaign]" id="account_utm_campaign" />
      <script>
        (function() {
          const params = new URLSearchParams(window.location.search)
          ["ref", "utm_source", "utm_campaign"].forEach((key) => {
            const value = params.get(key)
            if (value) {
              document.getElementById("account_" + key).value = value
            }
          })
        })()
      </script>
      """
    end
  end
end
