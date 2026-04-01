require Keila

Keila.if_cloud do
  defmodule KeilaCloudWeb.Components.RegistrationCloudData do
    use Phoenix.Component

    def registration_cloud_data(assigns) do
      ~H"""
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
