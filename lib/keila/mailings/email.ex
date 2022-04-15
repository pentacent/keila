defmodule Keila.Mailings.Email do
  @moduledoc """
  Defines functions for a rendering optimized email based on `Swoosh.Email` struct.

  The map `private` of the struct comprises an AST. The tree has to be rendered by `apply_ast/1`.
  """

  @type key :: atom() | binary()

  @ast_key :keila_ast
  @exception_list :keila_exception_list

  alias Swoosh.Email
  import Floki, only: [parse_document!: 2, raw_html: 2]
  import Swoosh.Email

  @type email :: Email.t()
  @typedoc """
  A abstract syntax tree representing a kind of hierarchical ordering, most likely a html tree.
  """
  @type ast_tree :: Floki.html_tree() | any()

  defmacro __using__(_) do
    quote do
      alias Keila.Mailings.Email
      import Keila.Mailings.Email
      import Swoosh.Email
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
  def get_ast(email), do: get_private(email, @ast_key)

  @spec get_private(email(), key()) :: any()
  def get_private(%Email{private: attributes}, key), do: Map.get(attributes, key)

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

  @doc """
  Puts an exception to a private exception list or throws.

  The `type` parameter can be:
  - _:error_ An unrecoverable error occured. The
  - _:warning_ There was a problem which was fixed or ignored.
  """
  @spec put_exception(email(), any(), atom()) :: email()
  def put_exception(email, error, type \\ :error) do
    case type do
      :error -> throw({email, error})
      :warning ->
        list = get_private(email, @exception_list)
        put_private(email, @exception_list, [error | list])
    end
  end
end
