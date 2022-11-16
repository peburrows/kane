defmodule Kane.TopicTest do
  use ExUnit.Case, async: true

  alias Kane.Topic
  alias Kane.GCPTestCredentials
  alias Kane.TestToken

  setup do
    bypass = Bypass.open()
    credentials = GCPTestCredentials.read!()
    {:ok, token} = TestToken.for_scope(Kane.oauth_scope())

    kane = %Kane{
      endpoint: "http://localhost:#{bypass.port}",
      token: token,
      project_id: Map.fetch!(credentials, "project_id")
    }

    {:ok, bypass: bypass, kane: kane}
  end

  describe "full_name/2" do
    test "getting full name", %{kane: kane} do
      name = "my-topic"
      topic = %Topic{name: name}
      project_id = kane.project_id

      assert "projects/#{project_id}/topics/#{name}" == Topic.full_name(topic, project_id)
    end
  end

  describe "create/2" do
    test "successfully creating a topic", %{kane: kane, bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert_access_token(conn)
        assert_body(conn, "")
        Plug.Conn.resp(conn, 201, ~s({"name": "projects/myproject/topics/mytopic"}))
      end)

      assert {:ok, %Topic{name: "test"}} = Topic.create(kane, "test")
    end

    test "failing to create because of Google error", %{kane: kane, bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert_access_token(conn)

        Plug.Conn.resp(
          conn,
          403,
          ~s({"error": {"code": 403, "message": "User not authorized to perform this action.", "status": "PERMISSION_DENIED"}})
        )
      end)

      assert {:error, _body, 403} = Topic.create(kane, "failed")
    end

    test "failing to create because of network error", %{kane: kane, bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, _something} = Topic.create(kane, "network-error")
    end
  end

  describe "find/2" do
    test "finding a topic", %{kane: kane, bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        [_, _, project, _, name] = String.split(conn.request_path, "/")
        Plug.Conn.resp(conn, 200, ~s({"name": "projects/#{project}/topics/#{name}"}))
      end)

      name = "finder"
      assert {:ok, %Topic{name: ^name}} = Topic.find(kane, name)
    end

    test "finding a topic with a fully-qualified name", %{kane: kane, bypass: bypass} do
      project_id = kane.project_id
      short_name = "fqn"
      full_name = "projects/#{project_id}/topics/#{short_name}"

      Bypass.expect(bypass, fn conn ->
        assert conn.request_path == "/#{full_name}"
        Plug.Conn.resp(conn, 200, ~s({"name":"#{full_name}"}))
      end)

      assert {:ok, %Topic{name: ^short_name}} = Topic.find(kane, full_name)
    end
  end

  describe "delete/2" do
    test "deleting a topic", %{kane: kane, bypass: bypass} do
      topic = %Topic{name: "delete-me"}

      Bypass.expect(bypass, fn conn ->
        assert_access_token(conn)
        Plug.Conn.resp(conn, 200, "")
      end)

      assert {:ok, _body, _code} = Topic.delete(kane, topic)
    end
  end

  describe "all/1" do
    test "listing all topics", %{kane: kane, bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        project_id = kane.project_id

        assert Regex.match?(~r/\/projects\/#{project_id}\/topics/, conn.request_path)

        Plug.Conn.resp(conn, 200, ~s({"topics": [
                                      {"name": "projects/#{project_id}/topics/mytopic1"},
                                      {"name": "projects/#{project_id}/topics/mytopic2"}
                                    ]}))
      end)

      {:ok, topics} = Topic.all(kane)
      assert is_list(topics)

      Enum.each(topics, fn t ->
        assert %Topic{} = t
      end)
    end
  end

  defp assert_access_token(conn) do
    [token] = Plug.Conn.get_req_header(conn, "authorization")
    assert Regex.match?(~r/Bearer/, token)
  end

  defp assert_body(conn, match) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    assert Regex.match?(~r/#{match}/, body)
  end
end
