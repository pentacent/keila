defmodule Keila.Test.Hasher do
  use ExUnit.Case
  alias Keila.Hasher

  @input "My name is Ozymandias, king of kings\nLook on my works, ye Mighty, and despair!"
  @hash_md5_raw <<56, 114, 4, 250, 42, 43, 140, 166, 79, 12, 38, 163, 167, 231, 209, 181>>
  @hash_md5_b32 "hbzaj6rkfogkmtyme2r2pz6rwu======"
  @hash_md5_b64 "OHIE+iorjKZPDCajp+fRtQ=="
  @hash_sha "7208ff22e6a465b2070b0130bce1f1d129745c1c"
  @hash_sha256 "475b8d521b295900117d970d3243fcf7bef27fb1f6786ae3af619416d6a6584a"

  setup_all do
    timestamp = System.os_time()

    file_path =
      System.tmp_dir!()
      |> Path.join("hasher-test-#{timestamp}")

    File.open!(file_path, [:write], fn file ->
      IO.write(file, @input)
    end)

    on_exit(fn ->
      File.rm!(file_path)
    end)

    {:ok, file_path: file_path}
  end

  @tag :hasher
  test "hash a binary" do
    md5_raw = Hasher.hash(@input, :md5, encoding: :raw)
    assert md5_raw == @hash_md5_raw

    md5_raw = Hasher.hash(@input, :md5, encoding: :base32)
    assert md5_raw == @hash_md5_b32

    md5_raw = Hasher.hash(@input, :md5, encoding: :base64)
    assert md5_raw == @hash_md5_b64

    sha = Hasher.hash(@input, :sha)
    assert sha == @hash_sha

    sha256_uppercase = Hasher.hash(@input, :sha256, case: :upper)
    assert sha256_uppercase == String.upcase(@hash_sha256)
  end

  @tag :hasher
  test "hashing with multiple algorithms" do
    hashes = Hasher.hash(@input, [:sha, :sha256])
    assert hashes == [@hash_sha, @hash_sha256]
  end

  @tag :hasher
  test "hash a stream" do
    {:ok, stream} = StringIO.open(@input)

    sha =
      stream
      |> IO.binstream(1)
      |> Hasher.hash_stream(:sha)

    assert sha == @hash_sha
  end

  @tag :hasher
  test "hash a file", context do
    sha = Hasher.hash_file(context[:file_path], :sha)
    assert sha == @hash_sha
  end
end
