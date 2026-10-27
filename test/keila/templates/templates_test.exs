defmodule Keila.TemplatesTest do
  use Keila.DataCase, async: true
  alias Keila.Templates
  alias Keila.Templates.{Html, Css, Template}

  doctest Keila.Templates.Html
  doctest Keila.Templates.Css

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))

    %{project: project, other_project: other_project}
  end

  @input_html """
  <div style="margin: 10px" class="foo">
    <a href="#">Link</a>
    <a href="#">Another Link</a>
  </div>
  """

  @input_css """
  /*
  Comments are ignored
  */
  .foo {
    background-color: #f0f;
    font-family: inherit;
  }
  div {
    padding: 10px;
  }
  a {
    color: blue; /* Comments are ignored everywhere */
  }
  """

  @expected_html """
                 <div style="margin:10px;background-color:#f0f;font-family:inherit;padding:10px" class="foo">
                   <a href="#" style="color:blue">Link</a>
                   <a href="#" style="color:blue">Another Link</a>
                 </div>
                 """
                 |> String.replace(~r{\n\s*}, "")

  @tag :templates
  test "inline css" do
    html = Html.parse_fragment!(@input_html)
    css = Css.parse!(@input_css)
    assert @expected_html == Html.apply_inline_styles(html, css) |> Html.to_fragment()
  end

  @tag :templates
  test "inline css with opts" do
    html = Html.parse_fragment!(@input_html)
    css = Css.parse!(@input_css)
    expected_html_without_inherit = @expected_html |> String.replace("font-family:inherit;", "")

    assert expected_html_without_inherit ==
             Html.apply_inline_styles(html, css, ignore_inherit: true) |> Html.to_fragment()
  end

  @tag :templates
  test "get CSS values by selector and property" do
    css = Css.parse!(@input_css)
    assert "#f0f" == Css.get_value(css, ".foo", "background-color")
  end

  @tag :templates
  test "create template", %{project: project} do
    params = params(:template)
    assert {:ok, %Template{}} = Templates.create_template(project.id, params)
  end

  @tag :templates
  test "clone template", %{project: project} do
    template = insert!(:template, project_id: project.id)

    {:ok, cloned_template} = Templates.clone_template(template.id, %{"name" => "My new name"})

    assert cloned_template.name == "My new name"
  end

  @tag :templates
  test "list templates", %{project: project} do
    templates = insert_n!(:template, 5, fn _ -> %{project_id: project.id} end)
    retrieved_templates = Templates.get_project_templates(project.id)

    assert Enum.count(templates) == Enum.count(retrieved_templates)

    for template <- retrieved_templates do
      assert template in templates
    end
  end

  @tag :templates
  test "delete template", %{project: project} do
    template = insert!(:template, project_id: project.id)
    assert :ok = Templates.delete_template(template.id)
    assert nil == Templates.get_template(template.id)
  end

  @tag :templates
  test "delete project templates", %{project: project} do
    templates = insert_n!(:template, 5, fn _ -> %{project_id: project.id} end)
    other_template = insert!(:template)

    assert :ok =
             Templates.delete_project_templates(
               project.id,
               Enum.map(templates, & &1.id) ++ [other_template.id]
             )

    assert [] == Templates.get_project_templates(project.id)
    assert other_template == Templates.get_template(other_template.id)
  end

  @tag :templates
  test "replaces the template of embedded emails in the project", %{
    project: project,
    other_project: other_project
  } do
    template = insert!(:template, project_id: project.id)
    replacement = insert!(:template, project_id: project.id)

    form =
      insert!(:contacts_form,
        project_id: project.id,
        welcome_email: build(:mailings_email, template_id: template.id),
        double_opt_in_email: build(:mailings_email, template_id: template.id)
      )

    # Emails migrated from the old form settings store integer template ids
    {:ok, integer_id} = Template.Id.dump(template.id)

    from(f in Keila.Contacts.Form,
      where: f.id == ^form.id,
      update: [
        set: [
          double_opt_in_email:
            fragment("jsonb_set(?, '{template_id}', ?)", f.double_opt_in_email, ^integer_id)
        ]
      ]
    )
    |> Repo.update_all([])

    other_form =
      insert!(:contacts_form,
        project_id: other_project.id,
        welcome_email: build(:mailings_email, template_id: template.id)
      )

    assert :ok =
             Templates.replace_project_email_templates(project.id, [template.id], replacement.id)

    assert %{
             welcome_email: %{template_id: welcome_template_id},
             double_opt_in_email: %{template_id: double_opt_in_template_id}
           } = Keila.Contacts.get_form(form.id)

    assert welcome_template_id == replacement.id
    assert double_opt_in_template_id == replacement.id

    assert Keila.Contacts.get_form(other_form.id).welcome_email.template_id == template.id

    assert :ok = Templates.delete_template(replacement.id)

    assert %{welcome_email: %{template_id: nil}, double_opt_in_email: %{template_id: nil}} =
             Keila.Contacts.get_form(form.id)
  end

  @tag :templates
  test "doesn't replace templates with a template from another project", %{
    project: project,
    other_project: other_project
  } do
    template = insert!(:template, project_id: project.id)
    other_template = insert!(:template, project_id: other_project.id)

    form =
      insert!(:contacts_form,
        project_id: project.id,
        welcome_email: build(:mailings_email, template_id: template.id)
      )

    assert {:error, :template_not_found} =
             Templates.replace_project_email_templates(
               project.id,
               [template.id],
               other_template.id
             )

    assert Keila.Contacts.get_form(form.id).welcome_email.template_id == template.id
  end

  @tag :templates
  test "update_template accepts mjml_body, html_body, text_body",
       %{project: project} do
    template = insert!(:template, project_id: project.id)

    params = %{
      "name" => "MJML Template",
      "mjml_body" =>
        "<mjml><mj-body><mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section></mj-body></mjml>",
      "html_body" => "<html><body>Hi</body></html>",
      "text_body" => "Hi"
    }

    assert {:ok, updated} = Templates.update_template(template.id, params)
    assert updated.mjml_body =~ "mj-text"
    assert updated.html_body == "<html><body>Hi</body></html>"
    assert updated.text_body == "Hi"
  end

  @tag :templates
  test "update_template can not change the type", %{project: project} do
    template = insert!(:template, project_id: project.id)

    assert {:ok, updated} = Templates.update_template(template.id, %{"type" => "mjml"})
    assert updated.type == template.type
  end

  @tag :templates
  test "create_template requires a type", %{project: project} do
    params = %{"name" => "No Type"}
    assert {:error, changeset} = Templates.create_template(project.id, params)
    assert "can't be blank" in errors_on(changeset).type
  end
end
