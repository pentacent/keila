defmodule KeilaWeb.Captcha do
  @moduledoc """
  Helper module for handling captchas.

  ## Configuration
  By default, the staging environment of hCaptcha is used.
  """

  use Phoenix.HTML

  @script_url_hcaptcha "https://hcaptcha.com/1/api.js"
  @script_url_friendlycaptcha "https://unpkg.com/friendly-challenge@0.9.11/widget.module.min.js"

  def captcha_tag() do
    [
      content_tag(:div, nil,
        class: div_class(),
        data_sitekey: config()[:site_key],
        data_theme: "dark"
      ),
      content_tag(:script, nil, src: script_url(), async: true, defer: true)
    ]
  end

  @spec get_captcha_response(map()) :: String.t() | nil
  def get_captcha_response(params) when is_map(params) do
    params[response_param()]
  end

  @spec captcha_valid?(String.t()) :: boolean()
  def captcha_valid?(response)

  def captcha_valid?(response) when response in [nil, ""], do: false

  def captcha_valid?(response) do
    config = config()
    body = request_body(response)

    with {:ok, response} <- HTTPoison.post(config[:url], body, [], recv_timeout: 5_000),
         {:ok, response_body} <- Jason.decode(response.body),
         %{"success" => true} <- response_body do
      true
    else
      _other -> false
    end
  end

  defp request_body(response) do
    config = config()

    case config[:provider] do
      :hcaptcha ->
        {:form, [sitekey: config[:site_key], secret: config[:secret_key], response: response]}

      :friendly_captcha ->
        {:form, [sitekey: config[:site_key], secret: config[:secret_key], solution: response]}
    end
  end

  defp script_url() do
    case config()[:provider] do
      :hcaptcha -> @script_url_hcaptcha
      :friendly_captcha -> @script_url_friendlycaptcha
    end
  end

  defp div_class() do
    case config()[:provider] do
      :hcaptcha -> "h-captcha"
      :friendly_captcha -> "frc-captcha"
    end
  end

  defp response_param() do
    case config()[:provider] do
      :hcaptcha -> "h-captcha-response"
      :friendly_captcha -> "frc-captcha-solution"
    end
  end

  defp config() do
    Application.get_env(:keila, KeilaWeb.Captcha)
  end
end
