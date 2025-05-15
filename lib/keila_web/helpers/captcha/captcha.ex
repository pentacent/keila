defmodule KeilaWeb.Captcha do
  @moduledoc """
  Helper module for handling captchas.

  ## Configuration
  By default, the staging environment of hCaptcha is used.
  """

  use Phoenix.HTML

  @default_urls [
    hcaptcha: [
      verify: "https://hcaptcha.com/siteverify",
      script: "https://hcaptcha.com/1/api.js"
    ],
    friendly_captcha: [
      verify: "https://api.friendlycaptcha.com/api/v1/siteverify",
      script: "https://unpkg.com/friendly-challenge@0.9.11/widget.module.min.js"
    ]
  ]

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
    body = request_body(response)

    with {:ok, response} <- HTTPoison.post(verify_url(), body, [], recv_timeout: 5_000),
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

  defp verify_url() do
    config = config()

    case config[:verify_url] do
      nil -> @default_urls[config[:provider]][:verify]
      verify_url -> verify_url
    end
  end

  defp script_url() do
    config = config()

    case config[:script_url] do
      nil -> @default_urls[config[:provider]][:script]
      verify_url -> verify_url
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
