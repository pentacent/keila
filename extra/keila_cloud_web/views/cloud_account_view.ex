require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudAccountView do
    use Phoenix.View,
      root: "extra/keila_cloud_web/templates",
      namespace: KeilaWeb

    use Phoenix.HTML
    import Phoenix.View
    import Phoenix.LiveView.Helpers
    import KeilaWeb.Gettext
    import KeilaWeb.ErrorHelpers
    import Ecto.Changeset
    alias KeilaCloud.Countries

    def country(changeset), do: get_field(changeset, :country)

    def administrative_areas(changeset) do
      case country(changeset) do
        nil -> []
        country -> Countries.administrative_area_options(country)
      end
    end

    def address_format(changeset) do
      case country(changeset) do
        nil -> nil
        country -> Countries.address_format(country)
      end
    end

    def required_fields(changeset) do
      case country(changeset) do
        nil -> nil
        country -> Countries.required_address_fields(country)
      end
    end

    def field_groups(changeset) do
      case address_format(changeset) do
        nil -> nil
        address_format -> format_to_field_groups(address_format["format"])
      end
    end

    defp format_to_field_groups(format, field_groups \\ [[]])

    @known_fields ~w[given_name additional_name family_name organization_name postal_code sorting_code dependent_locality locality administrative_area country address_line_1 sorting_code address_line_2 address_line_3]

    for field <- @known_fields do
      @field field
      defp format_to_field_groups("%" <> @field <> format, field_groups) do
        format_to_field_groups(format, add_in_last_group(field_groups, @field))
      end
    end

    @spacers [" ", ", ", " - ", "-", "/"]
    for spacer <- @spacers do
      @spacer spacer
      defp format_to_field_groups(@spacer <> format, field_groups),
        do: format_to_field_groups(format, field_groups)
    end

    defp format_to_field_groups("\n" <> format, field_groups),
      do: format_to_field_groups(format, field_groups ++ [[]])

    defp format_to_field_groups("", field_groups), do: field_groups

    defp add_in_last_group(groups, value) do
      List.update_at(groups, length(groups) - 1, &(&1 ++ [value]))
    end
  end
end
