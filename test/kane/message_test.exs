defmodule Kane.MessageTest do
  use ExUnit.Case
  alias Kane.Message
  alias Kane.Topic

  setup do
    bypass = Bypass.open()
    Application.put_env(:kane, :endpoint, "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass}
  end

  test "encoding the message body from a data structure" do
    data = %{phil?: "He's aweseom"}
    encoded = data |> Jason.encode!() |> Base.encode64()
    assert Message.encode_body(data) == encoded
  end

  test "encoding the message body from a string" do
    data = "we are just a string!"
    encoded = Base.encode64(data)
    assert Message.encode_body(data) == encoded
  end

  test "building the message data" do
    message = %Message{data: %{hello: "world"}, attributes: %{"random" => "attr"}}

    data = %{hello: "world"} |> Jason.encode!() |> Base.encode64()

    assert %{
             "messages" => [
               %{
                 "data" => ^data,
                 "attributes" => %{
                   "random" => "attr"
                 }
               }
             ]
           } = Message.data(message)
  end

  test "publishing a message", %{bypass: bypass} do
    {:ok, project} = Goth.Config.get(:project_id)
    topic = "publish"

    Bypass.expect(bypass, fn conn ->
      assert Regex.match?(~r{/projects/#{project}/topics/#{topic}:publish}, conn.request_path)
      Plug.Conn.resp(conn, 201, ~s({"messageIds": [ "19916711285" ]}))
    end)

    data = %{"my" => "message", "random" => "fields"}
    assert {:ok, %Message{id: id}} = Message.publish(%Message{data: data}, %Topic{name: topic})
    assert id != nil
  end

  test "publishing multiple messages", %{bypass: bypass} do
    {:ok, project} = Goth.Config.get(:project_id)
    topic = "publish-multi"
    ids = ["hello", "hi", "howdy"]

    Bypass.expect(bypass, fn conn ->
      assert Regex.match?(~r{/projects/#{project}/topics/#{topic}:publish}, conn.request_path)

      Plug.Conn.resp(
        conn,
        201,
        ~s({"messageIds": [ "#{Enum.at(ids, 0)}", "#{Enum.at(ids, 1)}", "#{Enum.at(ids, 2)}" ]})
      )
    end)

    data = [%{"hello" => "world"}, %{"hi" => "world"}, %{"howdy" => "world"}]

    assert {:ok, messages} =
             Message.publish(
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

  test "creating from subscription message" do
    ack = "123"
    id = "321"
    data = "eyJoZWxsbyI6IndvcmxkIn0="
    decoded = data |> Base.decode64!()
    time = "2016-01-24T03:07:33.195Z"
    attributes = %{key: "123"}

    assert {:ok,
            %Message{
              id: ^id,
              ack_id: ^ack,
              publish_time: ^time,
              data: ^decoded,
              attributes: ^attributes
            }} =
             Message.from_subscription(%{
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
