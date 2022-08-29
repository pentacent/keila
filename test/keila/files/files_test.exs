defmodule Keila.FilesTest do
  use Keila.DataCase, async: false
  use Keila.FileCase

  @test_file "test/keila/files/keila.png"
  @test_file_jpg "test/keila/files/keila.jpg"

  @tag :files
  test "Test media type by filename and file signature" do
    assert {:ok, "image/png"} = Files.MediaType.type_from_filename(@test_file)
    assert {:ok, "image/png"} = Files.MediaType.type_from_magic_number(@test_file)

    assert {:ok, "image/jpeg"} = Files.MediaType.type_from_filename(@test_file_jpg)
    assert {:ok, "image/jpeg"} = Files.MediaType.type_from_magic_number(@test_file_jpg)
  end

  @tag :files
  test "Store file, get URL, delete file" do
    project = insert!(:project)

    assert {:ok, file} =
             Files.store_file(project.id, @test_file,
               filename: "keila.png",
               type: "image/png"
             )

    url = Files.get_file_url(file.uuid)
    assert not is_nil(url) and String.starts_with?(url, "http")

    assert :ok == Files.delete_file(file.uuid)
  end

  @tag :files
  test "Get project files" do
    project = insert!(:project)
    project2 = insert!(:project)

    for _n <- 1..10 do
      {:ok, file} =
        Files.store_file(project.id, @test_file, filename: "keila.png", type: "image/png")

      file
    end

    assert %{count: 10} = Files.get_project_files(project.id, paginate: true)
    assert [] == Files.get_project_files(project2.id, paginate: false)
  end

  @tag :files
  test "Media type and extension match check" do
    project = insert!(:project)

    assert {:error, :type_mismatch} =
             Files.store_file(project.id, @test_file,
               filename: "keila.png",
               type: "image/jpeg"
             )
  end

  @tag :files
  test "Verify media type" do
    project = insert!(:project)

    assert {:error, :type_mismatch} = Files.store_file(project.id, @test_file, type: "image/jpeg")
  end

  @tag :files
  test "Verify file extension" do
    project = insert!(:project)

    assert {:error, :type_mismatch} =
             Files.store_file(project.id, @test_file, filename: "keila.jpg")
  end
end
