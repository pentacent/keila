defmodule Keila.Instance.ReleaseTest do
  use ExUnit.Case, async: true

  alias Keila.Instance.Release

  describe "new!/1" do
    test "accepts a plain semver version" do
      release =
        Release.new!(%{
          version: "0.30.2",
          published_at: ~U[2026-04-15 00:00:00Z],
          changelog: "Bug fixes"
        })

      assert release.version == "0.30.2"
    end

    test "strips a leading v prefix from the version" do
      release =
        Release.new!(%{
          version: "v0.30.2",
          published_at: ~U[2026-04-15 00:00:00Z],
          changelog: "Bug fixes"
        })

      assert release.version == "0.30.2"
    end
  end

  describe "new/1" do
    test "returns {:ok, release} for a valid v-prefixed version" do
      assert {:ok, release} =
               Release.new(%{
                 version: "v0.30.2",
                 published_at: ~U[2026-04-15 00:00:00Z],
                 changelog: "Bug fixes"
               })

      assert release.version == "0.30.2"
    end

    test "returns {:error, changeset} for an invalid version" do
      assert {:error, changeset} =
               Release.new(%{
                 version: "not-a-version",
                 published_at: ~U[2026-04-15 00:00:00Z],
                 changelog: "Bug fixes"
               })

      assert Keyword.has_key?(changeset.errors, :version)
    end
  end
end
