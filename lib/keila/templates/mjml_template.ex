defmodule Keila.Templates.MjmlTemplate do
  @moduledoc """
  Helper module for handling MJML templates.

  @doc """
  Removes `<keila-code>` wrapper tags from an MJML document, leaving
  their contents in place.
  This is necessary to avoid special characters inside of Liquid tags
  from being escaped when parsing the document.
  """
  @spec remove_code_blocks(String.t() | nil) :: String.t() | nil
  def remove_code_blocks(nil), do: nil

  def remove_code_blocks(mjml) when is_binary(mjml) do
    String.replace(mjml, ~r{</?keila-code\s*/?>}, "")
  end
end
