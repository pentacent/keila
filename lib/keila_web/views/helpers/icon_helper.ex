defmodule KeilaWeb.IconHelper do
  @moduledoc """
  Helper module for rendering icons as inline SVG.

  Icons are from [Heroicons](https://heroicons.com/) and placed in
  `priv/vendor/hero-icons-outline`.
  Icons from Font Awesome are placed in `priv/vendor/font-awesome`.

  All icon names from Heroicons are supported; hyphens are transformed to
  underscores (i.e. use `arrow_left` instead of `arrow-left`).

  # Usage
      render_icon(:icon_name)
      #=> {:safe, "<svg ..."}
  """

  require EEx

  @paths [
    Path.join(:code.priv_dir(:keila), "vendor/hero-icons-outline"),
    Path.join(:code.priv_dir(:keila), "vendor/keila-icons"),
    Path.join(:code.priv_dir(:keila), "vendor/social-icons"),
    Path.join(:code.priv_dir(:keila), "vendor/font-awesome")
  ]

  @filenames @paths
             |> Enum.flat_map(&File.ls!/1)
             |> Enum.filter(&(&1 =~ ~r{\.svg$}))
             |> Enum.sort()

  for path <- @paths do
    File.ls!(path)
    |> Enum.filter(fn filename -> filename =~ ~r{\.svg$} end)
    |> Enum.each(fn filename ->
      path = Path.join(path, filename)
      name = filename |> String.replace(".svg", "") |> String.replace("-", "_")
      eex = EEx.compile_file(path, [])
      @external_resource path

      def render_icon(unquote(String.to_atom(name))) do
        {:safe, unquote(eex)}
      end
    end)
  end

  def __mix_recompile__?() do
    @paths |> Enum.flat_map(&File.ls!/1) |> Enum.filter(&(&1 =~ ~r{\.svg$})) |> Enum.sort() !=
      @filenames
  end
end
