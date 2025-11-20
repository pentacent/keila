defmodule Keila do
  @moduledoc """
  This module provides functions and macros to differentiate between Keila and Keila Cloud
  as well as Keila's AGPLv3 code and the non-AGPLv3 "extra" code.
  """

  @extra? match?({:module, _}, Code.ensure_compiled(KeilaCloud))
  if @extra? do
    @cloud? KeilaCloud.cloud?()
  else
    @cloud? false
  end

  def __mix_recompile__?() do
    @extra? != match?({:module, _}, Code.ensure_loaded(KeilaCloud)) ||
      @cloud? != (@extra? and Keila.cloud?())
  end

  @doc """
  Returns `true` if Keila was built with non-AGPLv3 "extra" code.
  """
  def extra?, do: @extra?

  @doc """
  Returns `true` if Keila was built with non-AGPLv3 Keila Cloud code.
  """
  def cloud?, do: @cloud?

  defmacro if_extra(clauses) do
    build_if(@extra?, clauses)
  end

  defmacro if_cloud(clauses) do
    build_if(@cloud?, clauses)
  end

  defmacro unless_cloud(clauses) do
    build_if(!@cloud?, clauses)
  end

  defp build_if(condition, do: do_clause),
    do: build_if(condition, do: do_clause, else: :noop)

  defp build_if(condition, do: do_clause, else: else_clause) do
    if condition do
      quote do
        unquote(do_clause)
      end
    else
      if else_clause != :noop do
        quote do
          unquote(else_clause)
        end
      else
        []
      end
    end
  end
end
