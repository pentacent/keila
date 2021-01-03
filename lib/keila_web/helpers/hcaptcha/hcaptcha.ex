defmodule KeilaWeb.Hcaptcha do
  @moduledoc """
  Helper module for handling hCaptchas.

  Must be used with `KeilaWeb.Hcaptcha.Plug`

  ## Configuration
  By default, the staging environment of hCaptcha is used.
  # TODO Add info about prod config
  """

  use Phoenix.HTML

  @script_url "https://hcaptcha.com/1/api.js"

  def captcha_tag() do
    [
      content_tag(:div, nil,
        class: "h-captcha",
        data_sitekey: config()[:site_key],
        data_theme: "dark"
      ),
      content_tag(:script, nil, src: @script_url, async: true, defer: true)
    ]
  end

  @spec captcha_valid?(String.t()) :: boolean()
  def captcha_valid?(response)

  def captcha_valid?(response) when response in [nil, ""], do: false

  def captcha_valid?(response) do
    config = config()
    body = {:form, [sitekey: config[:site_key], secret: config[:secret_key], response: response]}

    with {:ok, response} <- HTTPoison.post(config[:url], body, [], recv_timeout: 5_000),
         {:ok, response_body} <- Jason.decode(response.body),
         %{"success" => true} <- response_body do
      true
    else
      _other -> false
    end
  end

  defp config() do
    Application.get_env(:keila, :hcaptcha)
  end
end
