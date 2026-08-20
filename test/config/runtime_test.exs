defmodule Keila.Config.RuntimeTest do
  use ExUnit.Case, async: true

  @smtp_host "smtp.example.test"

  test "disables STARTTLS when MAILER_ENABLE_STARTTLS is false" do
    config = runtime_mailer_config(MAILER_ENABLE_STARTTLS: "false", MAILER_ENABLE_SSL: "false")

    assert config[:tls] == :never
    refute Keyword.has_key?(config, :tls_options)
  end

  test "configures STARTTLS certificate options when MAILER_ENABLE_STARTTLS is true" do
    config = runtime_mailer_config(MAILER_ENABLE_STARTTLS: "true", MAILER_ENABLE_SSL: "false")

    assert config[:tls] == :always

    assert config[:tls_options] ==
             [certificate_options_match?: true, versions: [:"tlsv1.2"]]
  end

  test "retains direct SSL options when STARTTLS is disabled" do
    config = runtime_mailer_config(MAILER_ENABLE_STARTTLS: "false", MAILER_ENABLE_SSL: "true")

    assert config[:ssl] == true
    assert config[:sockopts] == [certificate_options_match?: true]
    assert config[:tls] == :never
    refute Keyword.has_key?(config, :tls_options)
  end

  defp runtime_mailer_config(mailer_env) do
    runtime_path = Path.expand("../../config/runtime.exs", __DIR__)

    script = """
    Application.put_env(:keila, KeilaWeb.Endpoint, secret_key_base: "runtime-test")
    config = Config.Reader.read!(#{inspect(runtime_path)}, env: :prod)

    mailer_config =
      config
      |> Keyword.fetch!(:keila)
      |> Keyword.fetch!(Keila.Auth.Emails)

    certificate_options = :tls_certificate_check.options(#{inspect(@smtp_host)})

    serializable_config =
      Enum.map(mailer_config, fn
        {:tls_options, options} ->
          {:tls_options,
           [
             certificate_options_match?: Keyword.drop(options, [:versions]) == certificate_options,
             versions: options[:versions]
           ]}

        {:sockopts, options} ->
          {:sockopts, [certificate_options_match?: options == certificate_options]}

        option ->
          option
      end)

    encoded_config = serializable_config |> :erlang.term_to_binary() |> Base.encode64()
    IO.puts("RUNTIME_MAILER_CONFIG=" <> encoded_config)
    """

    env =
      [
        {"MIX_ENV", "test"},
        {"DB_URL", "postgres://user:password@localhost/keila_runtime_test"},
        {"MAILER_TYPE", "smtp"},
        {"MAILER_SMTP_HOST", @smtp_host},
        {"MAILER_SMTP_FROM_EMAIL", "keila@example.test"},
        {"MAILER_SMTP_PASSWORD", "password"},
        {"SECRET_KEY_BASE", String.duplicate("secret", 16)},
        {"HASHID_SALT", "runtime-test"}
      ] ++ Enum.map(mailer_env, fn {key, value} -> {Atom.to_string(key), value} end)

    elixir = System.find_executable("elixir") || raise "elixir executable not found"
    erl_libs = Mix.Project.build_path() |> Path.join("lib") |> Path.expand()

    {output, status} =
      System.cmd(elixir, ["-e", script],
        env: [{"ERL_LIBS", erl_libs} | env],
        stderr_to_stdout: true
      )

    assert status == 0, output

    [encoded_config] =
      Regex.run(~r/^RUNTIME_MAILER_CONFIG=(.+)$/m, output, capture: :all_but_first)

    encoded_config
    |> Base.decode64!()
    |> :erlang.binary_to_term([:safe])
  end
end
