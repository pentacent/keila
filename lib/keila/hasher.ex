defmodule Keila.Hasher do
  @moduledoc """
  Module for hashing files, streams and iodata.

  ## Usage
  ```
  Keila.Hasher.hash("foo", :sha256)
  #=> "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"

  #Hashing a file
  Keila.Hasher.hash_file("/dev/null", :md5)
  #=> "d41d8cd98f00b204e9800998ecf8427e"

  #Using multiple hashing algorithms at once
  Keila.Hasher.hash("foo", [:md5, :sha])
  #=> ["acbd18db4cc2f85cedef654fccc4a4d8", "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33"]

  #Obtaining the raw bytes of the hash
  Keila.Hasher.hash("foo", :md5, encoding: :raw)
  #=> <<172, 189, 24, 219, 76, 194, 248, 92, 237, 239, 101, 79, 204, 196, 164, 216>>

  #Creating a hash from a stream
  {:ok, stream} = StringIO.open("foo")
  stream |> IO.binstream(1) |> Hasher.hash_stream(:sha)
  #=> "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33"
  ```

  ## Supported algorithms
  All algorithms supported by `:crypto.hash/2` can be used with Hasher:
  - md4
  - md5
  - ripemd160
  - sha
  - sha224
  - sha256
  - sha384
  - sha512

  ## Encoding
  By default, hashes are encoded as `base16` strings. Alternatively, the
  encoding can be specifie dwith the `:encoding` option:
  - `:raw`
  - `:base16`
  - `:base32`
  - `:base64`
  """

  # 1 MiB
  @stream_size 1_048_576

  @type option ::
          {:encoding, :raw | :base16 | :base32 | :base64}
          | {:case, :lower | :upper}

  @typedoc """
  Algorithms supported by `:crypto.hash/2`
  """
  @type hash_algorithm ::
          :md4 | :md5 | :ripemd160 | :sha | :sha224 | :sha256 | :sha384 | :sha512

  @doc """
  Hashes iodata with the given hashing algorithm(s).

  ## Supported algorithms
  All algorithms supported by `:crypto.hash/2` can be used with Hasher.

  ## Options
  - `:encoding` - Encoding of the hash output. Possible values: `:raw`,
    `:base16`, `base32`, `:base64`. Defaults to `:base16`
  - `:case` - When using encodings other than `:raw`. Possible values:
    `:lower`, `:upper`. Defaults to `:lower`

  ## Example
  ```
  Keila.Hasher.hash("foo", :sha256)
  #=> "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"
  ```
  """
  @spec hash(iodata, [hash_algorithm], [option]) :: [binary]
  @spec hash(iodata, hash_algorithm, [option]) :: binary

  def hash(iodata, algs, options \\ [])

  def hash(iodata, alg, options) when not is_list(alg),
    do: hash(iodata, [alg], options) |> Enum.at(0)

  def hash(iodata, algs, options) do
    algs
    |> Enum.map(&:crypto.hash(&1, iodata))
    |> Enum.map(&postprocess_hash(&1, options))
  end

  @doc """
    Hashes a stream with the given hashing algorithm(s).

    Please note that only finite streams can be hashed.

    For supported options, see `Keila.Hasher.hash/3`
  """
  @spec hash_stream(Stream.t(), [hash_algorithm], [option]) :: [binary]
  @spec hash_stream(Stream.t(), hash_algorithm, [option]) :: binary
  def hash_stream(stream, algs, options \\ [])

  def hash_stream(stream, alg, options) when not is_list(alg),
    do: hash_stream(stream, [alg], options) |> Enum.at(0)

  def hash_stream(stream, algs, options) do
    contexts = Enum.map(algs, &:crypto.hash_init(&1))

    stream
    |> Enum.reduce(contexts, fn data, contexts ->
      Enum.map(contexts, &:crypto.hash_update(&1, data))
    end)
    |> Enum.map(fn hash ->
      :crypto.hash_final(hash)
      |> postprocess_hash(options)
    end)
  end

  @doc """
    Streams and hashes a file at `path` with the given hashing algorithm(s).

    For supported options, see `Keila.Hasher.hash/3`
  """
  @spec hash_file(Path.t(), hash_algorithm, [option]) :: binary
  @spec hash_file(Path.t(), [hash_algorithm], [option]) :: [binary]
  def hash_file(path, algs, options \\ [])

  def hash_file(path, alg, options) when not is_list(alg),
    do: hash_file(path, [alg], options) |> Enum.at(0)

  def hash_file(path, algs, options) do
    Path.expand(path)
    |> File.stream!([], @stream_size)
    |> hash_stream(algs, options)
  end

  # Apply encoding and formatting
  @spec postprocess_hash(binary, [option]) :: binary
  defp postprocess_hash(hash, options) do
    case Keyword.get(options, :encoding, :base16) do
      :raw ->
        hash

      :base16 ->
        Base.encode16(hash, case: Keyword.get(options, :case, :lower))

      :base32 ->
        Base.encode32(hash, case: Keyword.get(options, :case, :lower))

      :base64 ->
        Base.encode64(hash, case: Keyword.get(options, :case, :lower))
    end
  end
end
