require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Mailings.SendWithKeila.Mx2 do
    @moduledoc """
    This module handles identity setup with SES and Swoosh configuration
    for the MX2 server using AWS SES.
    """

    require Logger
    alias KeilaCloud.Mailings.SendWithKeila
    alias Keila.Mailings

    @configuration_set "keila"

    @doc """
    Sets up a domain identity in AWS SES for the given sender.

    Creates a SES domain identity if not already created, configures MAIL FROM domain, and DKIM, then
    checks the verification status of MX and DKIM records.

    Returns {:ok, updated_sender} on success, {:error, reason} on failure.
    """
    def set_up_domain(sender) do
      with :ok <- ensure_domain_is_set(sender),
           :ok <- create_domain_identity_with_settings(sender),
           {:ok, verification_status} <- check_verification_status(sender) do
        update_sender_verification_status(sender, verification_status)
      end
    end

    @doc """
    Returns the Swoosh configuration for SWK SES.
    """
    def to_swoosh_config(_sender) do
      [
        adapter: Swoosh.Adapters.AmazonSES
      ] ++ aws_config()
    end

    @doc """
    Adds configuration set.
    """
    def put_provider_options(email, _sender) do
      Swoosh.Email.put_provider_option(email, :configuration_set_name, @configuration_set)
    end

    defp aws_config() do
      [
        region: Application.get_env(:keila, __MODULE__)[:region],
        access_key_id: Application.get_env(:keila, __MODULE__)[:access_key_id],
        secret_access_key: Application.get_env(:keila, __MODULE__)[:secret_access_key]
      ]
    end

    defp dkim_private_key() do
      Application.get_env(:keila, __MODULE__)[:dkim_private_key]
    end

    defp ensure_domain_is_set(%{config: %{swk_domain: domain}})
         when is_binary(domain) and domain != "",
         do: :ok

    defp ensure_domain_is_set(_), do: {:error, "swk domain not set"}

    defp create_domain_identity_with_settings(sender) do
      with :ok <- create_domain_identity(sender),
           :ok <- set_mail_from_domain(sender),
           :ok <- disable_feedback_forwarding(sender) do
        :ok
      end
    end

    defp create_domain_identity(sender) do
      domain = sender.config.swk_domain

      selector =
        sender |> SendWithKeila.subdomain(:dkim2) |> String.replace_suffix("._domainkey", "")

      dkim_private_key = dkim_private_key()

      %ExAws.Operation.JSON{
        http_method: :post,
        path: "/v2/email/identities",
        data: %{
          "EmailIdentity" => domain,
          "DkimSigningAttributes" => %{
            "DomainSigningPrivateKey" => dkim_private_key,
            "DomainSigningSelector" => selector
          }
        },
        service: :ses
      }
      |> ExAws.request(aws_config())
      |> case do
        {:ok, _response} ->
          :ok

        {:error, {:http_error, 400, %{headers: headers}}} = reason ->
          if Enum.member?(headers, {"x-amzn-ErrorType", "AlreadyExistsException"}),
            do: :ok,
            else: {:error, {"failed to create domain identity", reason}}

        {:error, reason} ->
          {:error, {"failed to create domain identity", reason}}
      end
    end

    defp check_verification_status(sender) do
      case get_email_identity(sender) do
        {:ok, %{"DkimAttributes" => dkim_attrs, "MailFromAttributes" => mail_from_attrs}} ->
          dkim_status = Map.get(dkim_attrs, "Status")
          mail_from_status = Map.get(mail_from_attrs, "MailFromDomainStatus")

          {:ok,
           %{
             dkim_verified?: dkim_status == "SUCCESS",
             mail_from_verified?: mail_from_status == "SUCCESS"
           }}

        {:ok, _response} ->
          {:ok,
           %{
             dkim_verified?: false,
             mail_from_verified?: false
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp get_email_identity(sender) do
      domain = sender.config.swk_domain

      %ExAws.Operation.JSON{
        http_method: :get,
        path: "/v2/email/identities/#{domain}",
        service: :ses
      }
      |> ExAws.request(aws_config())
      |> case do
        {:ok, identity} -> {:ok, identity}
        {:error, reason} -> {:error, {"failed to get email identity", reason}}
      end
    end

    # Updates the sender with the verification timestamp.
    # Only sets swk_mx2_set_up_at when both DKIM and MAIL FROM are verified.
    # Preserves existing timestamp if already set.
    defp update_sender_verification_status(sender, verification_status) do
      now = DateTime.utc_now(:second)

      set_up_at =
        if verification_status.dkim_verified? && verification_status.mail_from_verified? do
          sender.config.swk_mx2_set_up_at || now
        else
          nil
        end

      updated_config = %{
        id: sender.config.id,
        swk_mx2_set_up_at: set_up_at
      }

      case Mailings.update_sender(sender.id, %{config: updated_config},
             config_cast_opts: [with: &SendWithKeila.private_changeset/2]
           ) do
        {:ok, updated_sender} -> {:ok, updated_sender}
        {:error, reason} -> {:error, "Failed to update sender: #{inspect(reason)}"}
      end
    end

    defp set_mail_from_domain(sender) do
      domain = sender.config.swk_domain
      subdomain = SendWithKeila.subdomain(sender, :mx2)
      mail_from_domain = subdomain <> "." <> domain

      %ExAws.Operation.JSON{
        http_method: :put,
        path: "/v2/email/identities/#{domain}/mail-from",
        data: %{
          "MailFromDomain" => mail_from_domain,
          "BehaviorOnMxFailure" => "REJECT_MESSAGE"
        },
        service: :ses
      }
      |> ExAws.request(aws_config())
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, {"failed to set mail from domain", reason}}
      end
    end

    defp disable_feedback_forwarding(sender) do
      domain = sender.config.swk_domain

      %ExAws.Operation.JSON{
        http_method: :put,
        path: "/v2/email/identities/#{domain}/feedback",
        data: %{
          "EmailForwardingEnabled" => false
        },
        service: :ses
      }
      |> ExAws.request(aws_config())
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, {"failed to disable feedback forwarding", reason}}
      end
    end

    def from(sender) do
      if use_fallback_domain?(sender) do
        fallback_email = KeilaCloud.Mailings.SendWithKeila.fallback_from_email(sender)
        {sender.from_name, fallback_email}
      else
        {sender.from_name, sender.from_email}
      end
    end

    def reply_to(sender) do
      if use_fallback_domain?(sender) do
        {sender.from_name, sender.from_email}
      else
        if sender.reply_to_email, do: {sender.reply_to_name, sender.reply_to_email}
      end
    end

    def use_fallback_domain?(%{config: config}) do
      is_nil(config.swk_domain_verified_at) or is_nil(config.swk_mx2_set_up_at)
    end

    @doc """
    Attempts to remove an email address from the AWS SES suppression list.

    This function always returns `:ok`. If there is an error, the function still
    returns `:ok` and logs the error.
    """
    def maybe_remove_email_from_suppression_list(email) when is_binary(email) do
      %ExAws.Operation.JSON{
        http_method: :delete,
        path: "/v2/email/suppression/addresses/#{URI.encode_www_form(email)}",
        service: :ses
      }
      |> ExAws.request(aws_config())
      |> case do
        {:ok, _response} ->
          :ok

        {:error, {:http_error, 404, _}} ->
          :ok

        {:error, other} ->
          Logger.warning("Failed to remove email from SES suppression list: #{inspect(other)}")
      end
    end
  end
end
