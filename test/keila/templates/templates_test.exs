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

    %{project: project}
  end

  @input_html """
  <div style="margin: 10px" class="foo">
    <a href="#">Link</a>
    <a href="#">Another Link</a>
  </div>
  """

  @input_css """
  .foo {
    background-color: #f0f;
  }
  div {
    padding: 10px;
  }
  a {
    color: blue;
  }
  """

  @expected_html """
                 <div style="margin: 10px;background-color:#f0f;padding:10px" class="foo">
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
end
