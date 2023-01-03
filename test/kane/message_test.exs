defmodule Kane.MessageTest do
  use ExUnit.Case, async: true

  alias Kane.Message
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

  describe "publish/3" do
    test "publishes binary data", %{kane: kane, bypass: bypass} do
      topic = "publish"
      message = "hello world"

      Bypass.expect(bypass, fn conn ->
        assert_binary_message(conn, message)

        Plug.Conn.resp(conn, 201, ~s({"messageIds": [ "19916711285" ]}))
      end)

      assert {:ok, %Message{}} = Message.publish(kane, message, topic)
    end

    test "publishes json encodable data", %{kane: kane, bypass: bypass} do
      topic = "publish"
      message = %{"my" => "message", "random" => "fields"}

      Bypass.expect(bypass, fn conn ->
        assert_json_message(conn, message)

        Plug.Conn.resp(conn, 201, ~s({"messageIds": [ "19916711285" ]}))
      end)

      assert {:ok, %Message{}} = Message.publish(kane, message, topic)
    end

    test "publishes a message", %{kane: kane, bypass: bypass} do
      topic = "publish"

      message = %Message{
        data: %{"my" => "message", "random" => "fields"},
        attributes: [{"random", "attr"}]
      }

      Bypass.expect(bypass, fn conn ->
        assert_message(conn, message)

        Plug.Conn.resp(conn, 201, ~s({"messageIds": [ "19916711285" ]}))
      end)

      assert {:ok, %Message{}} = Message.publish(kane, message, %Topic{name: topic})
    end

    test "assigns the retuning id", %{kane: kane, bypass: bypass} do
      topic = "publish"
      message = "hello world"

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 201, ~s({"messageIds": [ "19916711285" ]}))
      end)

      assert {:ok, %Message{id: id}} = Message.publish(kane, message, topic)

      assert id == "19916711285"
    end

    test "requests to the correct path", %{kane: kane, bypass: bypass} do
      project_id = kane.project_id
      topic = "publish"
      message = "hello world"

      Bypass.expect(bypass, fn conn ->
        assert Regex.match?(
                 ~r{/projects/#{project_id}/topics/#{topic}:publish},
                 conn.request_path
               )

        Plug.Conn.resp(conn, 201, ~s({"messageIds": [ "19916711285" ]}))
      end)

      assert {:ok, %Message{}} = Message.publish(kane, message, topic)
    end

    test "publishes multiple messages", %{kane: kane, bypass: bypass} do
      project_id = kane.project_id
      topic = "publish-multi"
      ids = ["hello", "hi", "howdy"]

      Bypass.expect(bypass, fn conn ->
        assert Regex.match?(
                 ~r{/projects/#{project_id}/topics/#{topic}:publish},
                 conn.request_path
               )

        Plug.Conn.resp(
          conn,
          201,
          ~s({"messageIds": [ "#{Enum.at(ids, 0)}", "#{Enum.at(ids, 1)}", "#{Enum.at(ids, 2)}" ]})
        )
      end)

      data = [%{"hello" => "world"}, %{"hi" => "world"}, %{"howdy" => "world"}]

      assert {:ok, messages} =
               Message.publish(
                 kane,
                 [
                   %Message{data: Enum.at(data, 0)},
                   %Message{data: Enum.at(data, 1)},
                   %Message{data: Enum.at(data, 2)}
                 ],
                 %Topic{name: topic}
               )

      ids
      |> Enum.with_index()
      |> Enum.each(fn {id, i} ->
        m = Enum.at(messages, i)
        assert id == m.id
        assert Enum.at(data, i) == m.data
      end)
    end
  end

  describe "from_subscription!/1" do
    test "creating from subscription message" do
      ack = "123"
      id = "321"
      data = "eyJoZWxsbyI6IndvcmxkIn0="
      decoded = data |> Base.decode64!()
      time = "2016-01-24T03:07:33.195Z"
      attributes = %{key: "123"}

      assert %Message{
               id: ^id,
               ack_id: ^ack,
               publish_time: ^time,
               data: ^decoded,
               attributes: ^attributes
             } =
               Message.from_subscription!(%{
                 "ackId" => ack,
                 "message" => %{
                   "data" => data,
                   "attributes" => attributes,
                   "messageId" => id,
                   "publishTime" => time
                 }
               })
    end
  end

  defp assert_binary_message(conn, binary_data) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    [sent_message] =
      body
      |> Jason.decode!()
      |> Map.fetch!("messages")

    assert sent_message["data"] |> Base.decode64!() == binary_data
  end

  defp assert_json_message(conn, json_data) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    [sent_message] =
      body
      |> Jason.decode!()
      |> Map.fetch!("messages")

    assert sent_message["data"] |> Base.decode64!() |> Jason.decode!() == json_data
  end

  defp assert_message(conn, message) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    [sent_message] =
      body
      |> Jason.decode!()
      |> Map.fetch!("messages")

    assert sent_message["data"] |> Base.decode64!() |> Jason.decode!() == message.data
    assert sent_message["attributes"] == Map.new(message.attributes)
  end
end
