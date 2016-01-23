defmodule Kane.MessageTest do
  use ExUnit.Case
  alias Kane.Message
  alias Kane.Topic

  setup do
    bypass = Bypass.open
    Application.put_env(:kane, :endpoint, "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass}
  end

  test "building the message data" do
    message = %Message{data: %{"hello": "world"}, attributes: %{"random" => "attr"}}

    data = %{"hello": "world"} |> Poison.encode! |> Base.encode64
    assert %{
      "messages" => [%{
        "data" => ^data,
        "attributes" => %{
          "random" => "attr"
        }
      }]
    } = Message.data(message)
  end

  test "publishing a message", %{bypass: bypass} do
    {:ok, project} = Goth.Config.get(:project_id)
    topic = "publish"

    Bypass.expect bypass, fn conn ->
      assert Regex.match?(~r{/projects/#{project}/topics/#{topic}:publish}, conn.request_path)
      Plug.Conn.resp conn, 201, ~s({"messageIds": [ "19916711285" ]})
    end

    data = %{"my" => "message", "random" => "fields"}
    assert {:ok, %Message{id: id}} = Message.publish(%Message{data: data}, %Topic{name: topic})
    assert id != nil
  end
end
