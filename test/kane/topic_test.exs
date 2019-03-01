defmodule Kane.TopicTest do
  use ExUnit.Case
  alias Kane.Topic

  setup do
    bypass = Bypass.open()
    Application.put_env(:kane, :endpoint, "http://localhost:#{bypass.port}")
    {:ok, project} = Goth.Config.get(:project_id)
    {:ok, bypass: bypass, project: project}
  end

  test "getting full name", %{project: project} do
    name = "my-topic"
    assert "projects/#{project}/topics/#{name}" == %Topic{name: name} |> Topic.full_name()
  end

  test "successfully creating a topic", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert_access_token(conn)
      assert_body(conn, "")
      Plug.Conn.resp(conn, 201, ~s({"name": "projects/myproject/topics/mytopic"}))
    end)

    assert {:ok, %Topic{name: "test"}} = Topic.create("test")
  end

  test "failing to create because of Google error", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert_access_token(conn)

      Plug.Conn.resp(
        conn,
        403,
        ~s({"error": {"code": 403, "message": "User not authorized to perform this action.", "status": "PERMISSION_DENIED"}})
      )
    end)

    assert {:error, _body, 403} = Topic.create("failed")
  end

  test "failing to create because of network error", %{bypass: bypass} do
    Bypass.down(bypass)
    assert {:error, _something} = Topic.create("network-error")
  end

  test "finding a topic", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      [_, _, project, _, name] = String.split(conn.request_path, "/")
      Plug.Conn.resp(conn, 200, ~s({"name": "projects/#{project}/topics/#{name}"}))
    end)

    name = "finder"
    assert {:ok, %Topic{name: ^name}} = Topic.find(name)
  end

  test "finding a topic with a fully-qualified name", %{bypass: bypass} do
    {:ok, project} = Goth.Config.get(:project_id)
    short_name = "fqn"
    full_name = "projects/#{project}/topics/#{short_name}"

    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/#{full_name}"
      Plug.Conn.resp(conn, 200, ~s({"name":"#{full_name}"}))
    end)

    assert {:ok, %Topic{name: ^short_name}} = Topic.find(full_name)
  end

  test "deleting a topic", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert_access_token(conn)
      Plug.Conn.resp(conn, 200, "")
    end)

    assert {:ok, _body, _code} = %Topic{name: "delete-me"} |> Topic.delete()
  end

  test "listing all topics", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      {:ok, project} = Goth.Config.get(:project_id)
      assert Regex.match?(~r/\/projects\/#{project}\/topics/, conn.request_path)

      Plug.Conn.resp(conn, 200, ~s({"topics": [
                                    {"name": "projects/#{project}/topics/mytopic1"},
                                    {"name": "projects/#{project}/topics/mytopic2"}
                                  ]}))
    end)

    {:ok, topics} = Topic.all()
    assert is_list(topics)

    Enum.each(topics, fn t ->
      assert %Topic{} = t
    end)
  end

  # helpers
  defp assert_access_token(conn) do
    [token] = Plug.Conn.get_req_header(conn, "authorization")
    assert Regex.match?(~r/Bearer/, token)
  end

  defp assert_body(conn, match) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    assert Regex.match?(~r/#{match}/, body)
  end
end
