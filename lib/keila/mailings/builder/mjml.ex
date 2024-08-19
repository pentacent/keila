defmodule Keila.Mailings.Builder.MJML do
  @moduledoc """
  Builder for MJML emails.
  """
  require KeilaWeb.Gettext

  import Swoosh.Email
  import KeilaWeb.Gettext

  @spec put_body(Swoosh.Email.t(), String.t(), map()) :: Swoosh.Email.t()
  def put_body(email, mjml_content, assigns \\ %{}) do
    with {:ok, rendered_mjml} <- render_mjml(mjml_content),
         {:ok, html_body} <- render_liquid(rendered_mjml, assigns) do
      html_body(email, html_body)
    else
      {:error, reason} ->
        email |> text_body(reason) |> header("X-Keila-Invalid", reason)
    end
  end

  defp render_mjml(input) do
    case Mjml.to_html(input) do
      {:ok, output} ->
        {:ok, output}

      {:error, reason} ->
        {:error, gettext("Error compiling MJML: %{reason}", reason: reason)}
    end
  end

  defp render_liquid(input, assigns) do
    case Keila.Mailings.Builder.LiquidRenderer.render_liquid(input, assigns) do
      {:ok, output} ->
        {:ok, output}

      {:error, reason} ->
        {:error, gettext("Error compiling Liquid: %{reason}", reason: reason)}
    end
  end
end
