defmodule KeilaWeb.ApiNormalizer do
  import Plug.Conn
  import Phoenix.Controller, only: [render: 2]
  import KeilaWeb.ApiNormalizer.SchemaMapper

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    opts
    |> Keyword.get(:normalize, [])
    |> Enum.reverse()
    |> apply_normalizers(conn)
    |> maybe_render_errors()
  end

  defp apply_normalizers(normalizers, conn) do
    Enum.reduce(normalizers, conn, fn normalizer, conn ->
      case normalize(normalizer, conn.params) do
        {:ok, assign, normalized_value} ->
          assign(conn, assign, normalized_value)

        {:error, error} ->
          previous_errors = Map.get(conn.assigns, :errors, [])

          conn
          |> put_status(Keyword.fetch!(error, :status))
          |> assign(:errors, [error | previous_errors])
      end
    end)
  end

  defp maybe_render_errors(conn = %{assigns: %{errors: _}}) do
    conn
    |> halt()
    |> render("errors.json")
  end

  defp maybe_render_errors(conn), do: conn

  @doc """
  Normalize parameters for the API controller.
  Takes params and name of a normalizer as arguments, returns `:ok` tuple with
  assign name and normalized value.

  In case of invalid params, returns `{:error, [status: 3xx | 4xx | 5xx, title: String.t(), detail: String.t()]}`
  """
  @spec normalize(atom(), Map.t()) :: {:ok, atom(), term()} | {:error, Keyword.t()}
  def normalize(normalizer, params)

  def normalize(:pagination, %{"paginate" => opts}) do
    page = opts |> Map.get("page", "0") |> String.to_integer()
    page_size = opts |> Map.get("pageSize", "20") |> String.to_integer()
    {:ok, :pagination, page: page, page_size: page_size}
  end

  def normalize(:pagination, _), do: {:ok, :pagination, page: 0, page_size: 20}

  def normalize(:contacts_filter, params = %{"filter" => filter}) when is_binary(filter) do
    case Jason.decode(filter) do
      {:ok, filter} -> normalize(:contacts_filter, Map.replace!(params, "filter", filter))
      {:error, error} -> {:error, status: 400, detail: error}
    end
  end

  def normalize(:contacts_filter, %{"filter" => filter}) when is_map(filter) do
    if Keila.Contacts.Query.valid_opts?(filter: filter) do
      {:ok, :filter, filter}
    else
      {:error, status: 400, title: "Invalid filter"}
    end
  end

  def normalize(:contacts_filter, _) do
    {:ok, :filter, %{}}
  end

  def normalize({:data, name}, %{"data" => data}) do
    data =
      data
      |> Enum.map(fn {key, value} ->
        {to_snake_case(name, key), value}
      end)
      |> Enum.into(%{})

    {:ok, :data, data}
  end

  def normalize({:data, _}, _) do
    {:error, status: 400, title: "Missing `data` Member"}
  end
end
