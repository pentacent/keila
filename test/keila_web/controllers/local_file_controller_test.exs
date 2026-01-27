defmodule KeilaWeb.LocalFileControllerTest do
  use KeilaWeb.ConnCase, async: false
  use Keila.FileCase

  @test_file "test/keila/files/keila.png"

  @tag :files
  test "Serve file", %{conn: conn} do
    group = insert!(:group)
    project = insert!(:project, group: group)

    assert {:ok, file} =
             Files.store_file(project.id, @test_file,
               filename: "keila.png",
               type: "image/png"
             )

    path = Files.get_file_url(file.uuid) |> URI.parse() |> Map.fetch!(:path)

    assert File.read!(@test_file) == conn |> get(path) |> response(200)

    assert :ok == Files.delete_file(file.uuid)

    assert conn |> get(path) |> response(404)
  end
end
