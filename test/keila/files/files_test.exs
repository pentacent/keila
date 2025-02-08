defmodule Keila.FilesTest do
  use Keila.DataCase, async: false
  use Keila.FileCase

  alias Keila.Mailings

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
    assert nil == Files.get_file(file.uuid)
  end

  @tag :files
  test "detect file usage in campaigns" do
    project = insert!(:project)

    # Store a file
    {:ok, file} =
      Files.store_file(project.id, @test_file, filename: "keila.png", type: "image/png")

    file_url = Files.get_file_url(file.uuid)

    campaign_with_uuid =
      insert!(:mailings_campaign,
        project_id: project.id,
        json_body: %{"blocks" => [%{"type" => "image", "data" => %{"src" => file.uuid}}]}
      )

    campaign_with_url =
      insert!(:mailings_campaign,
        project_id: project.id,
        html_body: "<img src=\"#{file_url}\">"
      )

    uuid_results = Mailings.search_in_project_campaigns(project.id, file.uuid)
    assert length(uuid_results) == 2
    assert campaign_with_uuid.id in Enum.map(uuid_results, & &1.id)

    url_results = Mailings.search_in_project_campaigns(project.id, file_url)
    assert length(url_results) == 1
    assert campaign_with_url.id in Enum.map(url_results, & &1.id)

    other_project = insert!(:project)
    other_results = Mailings.search_in_project_campaigns(other_project.id, file.uuid)
    assert Enum.empty?(other_results)
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
  test "Get project file" do
    project = insert!(:project)
    file = insert!(:file, project: project)

    assert Files.get_project_file(project.id, file.uuid) == file
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
