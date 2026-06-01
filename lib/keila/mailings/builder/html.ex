defmodule Keila.Mailings.Builder.HTML do
  @moduledoc """
  Builder for HTML emails.
  """
  use KeilaWeb.Gettext
  import Swoosh.Email

  @spec put_body(Swoosh.Email.t(), String.t(), map()) :: Swoosh.Email.t()
  def put_body(email, html_content, assigns \\ %{}) do
    case render_liquid(html_content, assigns) do
      {:ok, html_body} ->
        html_body(email, html_body)

      {:error, reason} ->
        email |> text_body(reason) |> header("X-Keila-Invalid", reason)
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
