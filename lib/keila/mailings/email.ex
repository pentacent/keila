defmodule Keila.Mailings.Email do
  @moduledoc """
  Defines functions for a rendering optimized email based on `Swoosh.Email` struct.

  The map `private` of the struct comprises an AST. The tree has to be rendered by `apply_ast/1`.
  """

  @type key :: atom() | binary()

  @ast_key :keila_ast
  @exception_list :keila_exception_list

  alias Swoosh.Email
  import Floki
  import Swoosh.Email

  @type email :: Email.t()
  @typedoc """
  A abstract syntax tree representing a kind of hierarchical ordering, most likely a html tree.
  """
  @type ast_tree :: Floki.html_tree() | any()

  def __using__(_) do
    quote do
      alias Keila.Mailings.Email
      import Email
    end
  end

  @doc """
  Render the body of an AST-build email.

  The `converter` function has to take two arguments:
  1. AST from private email field
  2. Options for conversion
  """
  @spec apply_ast(email(), fun(), keyword(boolean())) :: email()
  def apply_ast(email, converter \\ &raw_html/2, options \\ []) do
    content = converter.(
      get_ast(email),
      options
    )
    text_body(email, content)
  end

  @spec get_ast(email()) :: ast_tree()
  defp get_ast(email), do: get_private(email, @ast_key)

  @spec get_private(email(), key()) :: any()
  defp get_private(%Email{private: attributes}, key), do: Map.get(attributes, key)

  @doc """
  Define the basis of an AST.

  Use an existing AST or let one be parsed for you.
  """
  @spec put_ast(email(), ast_tree() | binary(), fun) :: email()
  def put_ast(email, tree) when is_list(tree), do: put_private(email, @ast_key, tree)

  def put_ast(email, text, parser \\ &parse_document!/2, options \\ []) when is_binary(text) do
    tree = parser.(
      text,
      options
    )
    put_private(email, @ast_key, tree)
  end

