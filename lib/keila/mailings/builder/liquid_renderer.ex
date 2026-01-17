defmodule Keila.Mailings.Builder.LiquidRenderer do
  @moduledoc """
  Module to safely render Liquid templates from strings or pre-pared by `Solid`.
  """

  @doc """
  Safely renders a liquid template to a string.

  Solid can sometimes raise exceptions when rendering invalid templates, this
  module catches these exceptions and transforms them into an error tuple.
  """
  @spec render_liquid(String.t() | Solid.Template.t(), assigns :: map(), opts :: Keyword.take()) ::
          {:ok, String.t()} | {:error, String.t()}
  def render_liquid(input, assigns, opts \\ [])

  def render_liquid(input, assigns, opts) when is_binary(input) do
    try do
      case Solid.parse(input) do
        {:ok, template} -> render_liquid(template, assigns, opts)
        {:error, error = %Solid.TemplateError{}} -> {:error, template_error_to_string(error)}
      end
    rescue
      _e -> {:error, "Unexpected parsing error"}
    end
  end

  def render_liquid(input = %Solid.Template{}, assigns, opts) do
    try do
      result = input |> Solid.render!(assigns, opts) |> to_string()

      {:ok, result}
    rescue
      _error ->
        {:error, "Unexpected rendering error"}
    end
  end

  defp template_error_to_string(%Solid.TemplateError{errors: errors}) do
    errors
    |> Enum.map(fn
      %Solid.ParserError{meta: %{line: line, column: column}, reason: reason, text: text} -> "Parsing error in line #{line}:#{column}: #{reason} (near #{text})"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Parse and render a string as a liquid template and then transform from
  Markdown to HTML.
  """
  @spec render_liquid_and_markdown(input :: String.t(), assigns :: map()) ::
          {:ok, html :: String.t()} | {:error, String.t()}
  def render_liquid_and_markdown(input, assigns) do
    with {:ok, markdown} <- render_liquid(input, assigns),
         {:ok, html} <- render_markdown(markdown) do
      {:ok, markdown, html}
    end
  end

  defp render_markdown(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _} -> {:ok, html}
      {:error, _, _} -> {:error, "Error processing Markdown"}
    end
  end

  @doc """
  Processes assigns to ensure they can be safely used for Liquid template rendering.

  Structs are converted to maps, atoms to strings, and tuples to lists. All map keys
  are converted to string keys. Processing is done recursively.
  """
  @spec process_assigns(any()) :: any()
  def process_assigns(value)
      when is_number(value) or is_binary(value) or
             is_boolean(value) or is_nil(value) do
    value
  end

  def process_assigns(value) when is_atom(value) do
    Atom.to_string(value)
  end

  def process_assigns(value) when is_tuple(value) do
    Tuple.to_list(value)
  end

  def process_assigns(value) when is_struct(value) do
    process_assigns(Map.from_struct(value))
  end

  def process_assigns(value) when is_map(value) do
    Enum.map(value, fn {key, value} ->
      key = to_string(key)
      value = process_assigns(value)
      {key, value}
    end)
    |> Enum.filter(fn
      {"__" <> _, _} -> false
      _ -> true
    end)
    |> Enum.into(%{})
  end

  def process_assigns(value) when is_list(value) do
    Enum.map(value, &process_assigns/1)
  end
end
