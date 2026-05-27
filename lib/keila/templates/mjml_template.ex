defmodule Keila.Templates.MjmlTemplate do
  @moduledoc """
  Helper module for handling MJML templates.
  """

  defmodule Slot do
    @moduledoc """
    A parsed keila-content slot definition: the slot's `name` and its `default_content`
    """

    @enforce_keys [:name, :default_content]
    defstruct [:name, :default_content]

    @type t :: %__MODULE__{name: String.t(), default_content: String.t() | nil}
  end

  @doc """
  Returns the list of content slot definitions in an MJML document.
  """
  @spec get_content_slots(String.t() | nil) :: [Slot.t()]
  def get_content_slots(nil), do: []

  def get_content_slots(mjml) when is_binary(mjml) do
    with {:ok, tree} <- Floki.parse_fragment(mjml) do
      tree
      |> Floki.find("mj-body > keila-content")
      |> Enum.map(fn {_tag, attrs, children} ->
        name = attr_value(attrs, "name")

        if is_binary(name) and name != "" do
          %Slot{name: name, default_content: Floki.raw_html(children)}
        end
      end)
      |> Enum.reject(&is_nil/1)
    else
      _ -> []
    end
  end

  @doc """
  Merges a map of named content slots into the given MJML.
  """
  @spec merge_content_slots(String.t() | nil, map() | nil) :: String.t() | nil
  def merge_content_slots(nil, _content), do: nil

  def merge_content_slots(mjml, content) when is_binary(mjml) do
    content = stringify_keys(content || %{})

    with {:ok, tree} <- Floki.parse_fragment(mjml) do
      tree
      |> Floki.traverse_and_update(fn
        {"mj-body", attrs, children} ->
          updated_children = Enum.flat_map(children, &maybe_merge_content_slot(&1, content))
          {"mj-body", attrs, updated_children}

        other ->
          other
      end)
      |> Floki.raw_html(encode: false)
    else
      _ -> mjml
    end
  end

  defp maybe_merge_content_slot({"keila-content", attrs, children}, content),
    do: merge_content_slot(attrs, children, content)

  defp maybe_merge_content_slot(other, _), do: [other]

  defp merge_content_slot(attrs, default_content, content) do
    name =
      case attr_value(attrs, "name") do
        name when is_binary(name) and name != "" -> name
        _ -> nil
      end

    if not is_nil(name) and Map.has_key?(content, name) do
      try_parse_fragment(content[name], default_content)
    else
      default_content
    end
  end

  defp try_parse_fragment(value, fallback) when is_binary(value) do
    case Floki.parse_fragment(value) do
      {:ok, tree} -> tree
      _ -> fallback
    end
  end

  defp try_parse_fragment(_value, fallback), do: fallback

  defp attr_value(attrs, name) do
    case List.keyfind(attrs, name, 0) do
      {^name, value} -> value
      _ -> nil
    end
  end

  defp stringify_keys(values) when is_map(values) do
    Enum.into(values, %{}, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      pair -> pair
    end)
  end
end
