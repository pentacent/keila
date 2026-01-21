require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Billing.Features do
    @moduledoc """
    This module provides the `feature_available?/2` function to determine whether
    a certain feature is covered by the current plan of a project’s account on
    Keila Cloud.
    """

    alias Keila.Accounts
    alias KeilaCloud.Billing
    alias Keila.Projects.Project

    @features ~w[double_opt_in welcome_email]a
    @type feature :: :double_opt_in | :welcome_email

    @doc """
    Returns `true` if the given feature is available for the specified project.

    Always returns `true` if Billing is not enabled.
    """
    @spec feature_available?(Project.id(), feature) :: boolean()
    def feature_available?(project_id, feature) when feature in @features do
      if Billing.billing_enabled?() do
        account = Accounts.get_project_account(project_id)
        do_feature_available?(account, feature)
      else
        true
      end
    end

    defp do_feature_available?(account, :double_opt_in) do
      case Accounts.get_credits(account.id) do
        {n, _} when n > 0 -> true
        _other -> false
      end
    end

    defp do_feature_available?(account, :welcome_email) do
      case Accounts.get_credits(account.id) do
        {n, _} when n > 0 -> true
        _other -> false
      end
    end
  end
end
