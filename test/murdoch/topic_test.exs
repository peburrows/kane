defmodule Murdoch.TopicTest do
  use ExUnit.Case
  alias Murdoch.Topic

  setup do
    bypass = Bypass.open
    Application.put_env(:murdoch, :endpoint, "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass}
  end

  test "successfully creating a topic", %{bypass: bypass} do
    Bypass.expect bypass, fn conn ->
      [token] = Plug.Conn.get_req_header conn, "authorization"

      assert Regex.match?(~r/Bearer/, token)
      {:ok, body, _conn} = Plug.Conn.read_body conn
      assert body == ""
      Plug.Conn.resp conn, 201, ~s({"name": "projects/myproject/topics/mytopic"})
    end

    assert {:ok, %Topic{name: "test"}} = Topic.create("test")
  end

  test "failing because of Google error", %{bypass: bypass} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp conn, 403, ~s({"error": {"code": 403, "message": "User not authorized to perform this action.", "status": "PERMISSION_DENIED"}})
    end

    assert {:error, _body, 403} = Topic.create("failed")
  end

  test "failing because of network error", %{bypass: bypass} do
    Bypass.down(bypass)
    assert {:error, _something} = Topic.create("network-error")
  end
end
