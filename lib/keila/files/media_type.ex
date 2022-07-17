defmodule Keila.Files.MediaType do
  @moduledoc """
  Module for determining and comparing the media type of a file.

  Media types derived from file names and from magic numbers
  may be unreliable. Use the functions in this module for plausibility checks,
  not for security-related purposes.

  This module currently only supports image types, i.e.
  - `image/jpg`
  - `image/png`
  - `image/gif`
  """

  @doc """
  Returns the media type inferred from the given file name.
  """
  @spec type_from_filename(String.t()) :: {:ok, String.t()} | :error
  def type_from_filename(path) do
    path
    |> String.downcase()
    |> Path.extname()
    |> do_type_from_filename()
  end

  defp do_type_from_filename(".jpg"), do: {:ok, "image/jpg"}
  defp do_type_from_filename(".jpeg"), do: {:ok, "image/jpg"}
  defp do_type_from_filename(".png"), do: {:ok, "image/png"}
  defp do_type_from_filename(".gif"), do: {:ok, "image/gif"}
  defp do_type_from_filename(_), do: {:error, :unknown_type}

  @doc """
  Returns the media type inferred from reading the first bytes of a file.
  """
  @spec type_from_magic_number(String.t()) :: {:ok, String.t()} | {:error, term}
  def type_from_magic_number(path) do
    File.open(path, [:read], fn file ->
      file
      |> IO.binread(8)
      |> do_type_from_magic_number()
    end)
    |> strip_extra_ok()
  end

  defp do_type_from_magic_number(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <> _),
    do: {:ok, "image/png"}

  defp do_type_from_magic_number(<<0xFF, 0xD8, 0xFF, 0xDB>> <> _), do: {:ok, "image/jpg"}
  defp do_type_from_magic_number(<<0xFF, 0xD8, 0xFF, 0xE0>> <> _), do: {:ok, "image/jpg"}
  defp do_type_from_magic_number(<<0xFF, 0xD8, 0xFF, 0xEE>> <> _), do: {:ok, "image/jpg"}

  defp do_type_from_magic_number(<<0x47, 0x49, 0x46, 0x38, 0x37, 0x61>> <> _),
    do: {:ok, "image/gif"}

  defp do_type_from_magic_number(<<0x47, 0x49, 0x46, 0x38, 0x39, 0x61>> <> _),
    do: {:ok, "image/gif"}

  defp do_type_from_magic_number(_), do: {:error, :unknown_type}

  defp strip_extra_ok({:ok, result}), do: result
  defp strip_extra_ok(result), do: result

  @doc """
  Returns true if the media type from the file extension matches the magic
  number media type.

  This is useful when validating files with formats derived from other formats,
  e.g. formats based on the zip file format, such as ODF.
  """
  @spec type_match?(String.t(), String.t()) :: boolean()
  def type_match?(filename_type, magic_number_type)
  def type_match?(filename_type, magic_number_type), do: filename_type == magic_number_type
end
