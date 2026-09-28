defmodule Keila.Mailings.Email do
  use Keila.Schema, prefix: "eml"
  alias Keila.Projects.Project
  alias Keila.Templates.Template
  alias Keila.Mailings.Renderer

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

  schema "mailings_emails" do
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

    belongs_to :project, Project, type: Project.Id
    belongs_to :template, Template, type: Template.Id

    timestamps()
  end

  @spec creation_changeset(t(), map(), Project.id()) :: Ecto.Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params, project_id) do
    struct
    |> cast(params, @content_fields)
    |> put_change(:project_id, project_id)
    |> validate_required([:project_id])
    |> validate_content()
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t(t())
  def update_changeset(struct = %__MODULE__{}, params) do
    struct
    |> cast(params, @content_fields)
    |> validate_content()
  end

  defp validate_content(changeset) do
    changeset
    |> cast_embed(:editor_config)
    |> validate_required([:type])
    |> validate_body()
    |> validate_assoc_project(:template, Template)
  end

  @body_fields %{
    text: :text_body,
    markdown: :text_body,
    html: :html_body,
    mjml: :mjml_body,
    block: :json_body
  }

  # An email needs the body for its type.
  defp validate_body(changeset) do
    type = get_field(changeset, :type)

    case Map.fetch(@body_fields, type) do
      {:ok, body_field} -> validate_body(changeset, type, body_field)
      :error -> changeset
    end
  end

  # Text, HTML, and MJML templates can supply the body through content slots,
  # so the body is optional when such a template is set.
  defp validate_body(changeset, type, body_field) when type in [:text, :html, :mjml] do
    if is_nil(get_field(changeset, :template_id)) do
      validate_required(changeset, [body_field], message: "can't be blank without a template")
    else
      changeset
    end
  end

  # Markdown and block emails always need a body because their templates only
  # provide the layout.
  defp validate_body(changeset, _type, body_field) do
    validate_required(changeset, [body_field])
  end

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
