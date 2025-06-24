require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Countries do
    alias Cldr.Territory

    @paddle_excluded_countries ~w[AF BY MM CF CU CD HT IR LY ML AN NI KP RU SO SS SD SY VE YE ZW]a

    def list_countries() do
      Territory.country_codes()
      |> Enum.reject(&(&1 in @paddle_excluded_countries))
    end

    def country_options(locale) do
      list_countries()
      |> Enum.map(fn country_code ->
        case Territory.display_name(country_code, locale: locale) do
          {:ok, name} -> {name, country_code}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&elem(&1, 0))
    end

    def administrative_areas(country) do
      case Cldr.Territory.known_territory_subdivisions(country, Keila.Cldr) do
        {:ok, subdivisions} -> subdivisions
        _other -> []
      end
    end

    def administrative_area_options(country) do
      administrative_areas(country)
      |> Enum.map(&{Cldr.Territory.from_subdivision_code!(&1, Keila.Cldr), &1})
      |> Enum.sort_by(&elem(&1, 0))
    end

    @address_formats File.stream!("extra/vendor/address_formats.jsonl")
                     |> Stream.map(&Jason.decode!/1)
                     |> Stream.map(&{&1["country_code"], &1})
                     |> Enum.into(%{})

    @default_address_format %{
      "format" =>
        "%given_name %family_name\n%organization_name\n%address_line_1\n%address_line_2\n%address_line_3\n%postal_code\n%locality\n%administrative_area",
      "required_fields" => ["address_line_1", "locality"]
    }

    def address_format(country) do
      @address_formats[country] || @default_address_format
    end

    def required_address_fields(country) do
      case address_format(country) do
        %{"required_fields" => required_fields} when is_list(required_fields) -> required_fields
        _ -> @default_address_format["required_fields"]
      end
    end
  end
end
