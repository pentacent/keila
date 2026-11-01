defmodule Keila.Mailings.Email do
  use Ecto.Schema
  import Ecto.Changeset
  alias Keila.Templates.Template
  alias Keila.Mailings.Renderer

  @type t :: %__MODULE__{}

  @type recipient ::
          Keila.Contacts.Contact.t() | {name :: String.t() | nil, email :: String.t()} | nil

  @content_fields [
    :type,
    :subject,
    :preview_text,
    :text_body,
    :html_body,
    :mjml_body,
    :json_body,
    :text_content,
    :html_content,
    :mjml_content,
    :template_id
  ]

  embedded_schema do
    field :type, Ecto.Enum, values: [text: 0, html: 1, mjml: 10, block: 20, markdown: 30]
    field :subject, :string
    field :preview_text, :string
    field :text_body, :string
    field :html_body, :string
    field :mjml_body, :string
    field :json_body, :map
    field :text_content, :map
    field :html_content, :map
    field :mjml_content, :map

    embeds_one :editor_config, __MODULE__.EditorConfig, on_replace: :update

    field :template_id, Template.Id
    field :template, :any, virtual: true
  end

  @doc """
  Casts and validates an `Email`.

  ## Options
  - `:require_content` - When `false`, the subject and the body of Markdown
    emails are not required. Use this for emails whose empty content is filled
    with default content before rendering. Defaults to `true`.
  """
  # TODO: Once Markdown support is added to MJML/HTML templates, they should
  # also be allowed to be empty here when require_content: false
  @spec changeset(t(), map(), Keyword.t()) :: Ecto.Changeset.t(t())
  def changeset(struct \\ %__MODULE__{}, params, opts \\ []) do
    struct
    |> cast(params, @content_fields)
    |> cast_embed(:editor_config)
    |> validate_required([:type])
    |> validate_content(Keyword.get(opts, :require_content, true))
  end

  defp validate_content(changeset, true) do
    changeset
    |> validate_subject()
    |> validate_body(get_field(changeset, :type))
  end

  defp validate_content(changeset, false) do
    case get_field(changeset, :type) do
      :markdown -> changeset
      type -> validate_body(changeset, type)
    end
  end

  # A subject is required unless a template has been specified
  defp validate_subject(changeset) do
    if is_nil(get_field(changeset, :template_id)) do
      validate_required(changeset, [:subject], message: "can't be blank when no template is set")
    else
      changeset
    end
  end

  @body_fields %{
    text: :text_body,
    markdown: :text_body,
    html: :html_body,
    mjml: :mjml_body,
    block: :json_body
  }

  # Text, HTML, and MJML templates can supply the body, making the body optional.
  defp validate_body(changeset, type) when type in [:text, :html, :mjml] do
    if is_nil(get_field(changeset, :template_id)) do
      body_field = Map.fetch!(@body_fields, type)

      validate_required(changeset, [body_field],
        message: "can't be blank when no template is set"
      )
    else
      changeset
    end
  end

  defp validate_body(changeset, type) when type in [:block, :markdown] do
    body_field = Map.fetch!(@body_fields, type)
    validate_required(changeset, [body_field])
  end

  defp validate_body(changeset, nil), do: changeset

  @doc """
  Builds a `Keila.Mailings.Renderer.Input` from the given email.

  `template` must be preloaded before calling this function.
  """
  @spec to_input(t(), recipient(), map()) :: Renderer.Input.t()
  def to_input(%__MODULE__{} = email, recipient, assigns \\ %{}) do
    assigns =
      Map.put_new(assigns, "campaign", %{
        "subject" => email.subject,
        "preview_text" => email.preview_text
      })

    {contact, recipient_name, recipient_email} =
      case recipient do
        %Keila.Contacts.Contact{} = contact -> {contact, nil, nil}
        {name, email} -> {nil, name, email}
        nil -> {nil, nil, nil}
      end

    %Renderer.Input{
      type: email.type,
      subject: email.subject,
      text_body: email.text_body,
      html_body: email.html_body,
      mjml_body: email.mjml_body,
      json_body: email.json_body,
      text_content: email.text_content,
      html_content: email.html_content,
      mjml_content: email.mjml_content,
      template: email.template,
      contact: contact,
      recipient_name: recipient_name,
      recipient_email: recipient_email,
      assigns: assigns
    }
  end
end

defimpl Keila.Mailings.Renderable, for: Keila.Mailings.Email do
  defdelegate to_input(email, recipient, assigns), to: Keila.Mailings.Email
end

defmodule Keila.Mailings.Email.EditorConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :enable_wysiwyg, :boolean, default: true
  end

  @type t :: %__MODULE__{}

  def changeset(struct \\ %__MODULE__{}, params) do
    cast(struct, params, [:enable_wysiwyg])
  end
end
