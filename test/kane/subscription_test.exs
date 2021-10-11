defmodule Kane.SubscriptionTest do
  use ExUnit.Case
  alias Kane.Subscription
  alias Kane.Topic
  alias Kane.Message

  setup do
    bypass = Bypass.open()
    Application.put_env(:kane, :endpoint, "http://localhost:#{bypass.port}")
    {:ok, project} = Goth.Config.get(:project_id)
    {:ok, bypass: bypass, project: project}
  end

  test "generating the create path", %{project: project} do
    name = "path-sub"
    sub = %Subscription{name: name}

    assert "projects/#{project}/subscriptions/#{name}" == Subscription.path(sub, :create)
  end

  test "creating the JSON for creating a subscription", %{project: project} do
    name = "sub-json"
    topic = "sub-json-topic"

    sub = %Subscription{
      name: name,
      topic: %Topic{name: topic},
      filter: "attributes:domain"
    }

    assert %{
             "topic" => "projects/#{project}/topics/#{topic}",
             "ackDeadlineSeconds" => 10,
             "filter" => "attributes:domain"
           } == Subscription.data(sub, :create)
  end

  test "finding a subscription", %{bypass: bypass, project: project} do
    name = "found-sub"
    topic = "found-sub-topic"

    Bypass.expect(bypass, fn conn ->
      assert conn.method == "GET"
      assert Regex.match?(~r{projects/#{project}/subscriptions/#{name}}, conn.request_path)

      Plug.Conn.send_resp(
        conn,
        200,
        Jason.encode!(%{name: name, topic: topic, ackDeadlineSeconds: 20})
      )
    end)

    assert {:ok,
            %Subscription{
              name: ^name,
              topic: %Topic{name: ^topic},
              ack_deadline: 20
            }} = Subscription.find(name)
  end

  test "creating a subscription", %{bypass: bypass} do
    name = "create-sub"
    topic = "topic-to-sub"
    sub = %Subscription{name: name, topic: %Topic{name: topic}}

    sname = Subscription.full_name(sub)
    tname = Topic.full_name(sub.topic)

    Bypass.expect(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert body ==
               %{"topic" => tname, "ackDeadlineSeconds" => sub.ack_deadline} |> Jason.encode!()

      assert conn.method == "PUT"
      assert_content_type(conn, "application/json")

      Plug.Conn.send_resp(conn, 201, ~s({
                                           "name": "#{sname}",
                                           "topic": "#{tname}",
                                           "ackDeadlineSeconds": 10
                                        }))
    end)

    assert {:ok, %Subscription{topic: %Topic{name: ^topic}, name: ^name, ack_deadline: 10}} =
             Subscription.create(sub)
  end

  test "creating a subscription with filter includes a filter in the request body", %{
    bypass: bypass
  } do
    name = "create-sub"
    topic = "topic-to-sub"
    filter = "attributes:domain"

    sub = %Subscription{name: name, topic: %Topic{name: topic}, filter: filter}

    sname = Subscription.full_name(sub)
    tname = Topic.full_name(sub.topic)

    Bypass.expect(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert body ==
               %{
                 "topic" => tname,
                 "ackDeadlineSeconds" => sub.ack_deadline,
                 "filter" => filter
               }
               |> Jason.encode!()

      assert conn.method == "PUT"
      assert_content_type(conn, "application/json")

      Plug.Conn.send_resp(conn, 201, ~s({
                                           "name": "#{sname}",
                                           "topic": "#{tname}",
                                           "ackDeadlineSeconds": 10,
                                           "filter": "#{filter}"
                                        }))
    end)

    assert {:ok,
            %Subscription{
              topic: %Topic{name: ^topic},
              name: ^name,
              ack_deadline: 10,
              filter: ^filter
            }} = Subscription.create(sub)
  end

  test "includes expiration keys when creating a subscription", %{
    bypass: bypass
  } do
    name = "create-sub"
    topic = "topic-to-sub"
    expires_in = 24 |> :timer.hours() |> to_seconds()
    message_retention = 10 |> :timer.minutes() |> to_seconds()

    sub = %Subscription{
      name: name,
      topic: %Topic{name: topic},
      expires_in: expires_in,
      message_retention_duration: message_retention
    }

    sname = Subscription.full_name(sub)
    tname = Topic.full_name(sub.topic)

    Bypass.expect(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert body ==
               %{
                 "topic" => tname,
                 "ackDeadlineSeconds" => sub.ack_deadline,
                 "messageRetentionDuration" => "#{message_retention}s",
                 "expirationPolicy" => %{
                   "ttl" => "#{expires_in}s"
                 }
               }
               |> Jason.encode!()

      assert conn.method == "PUT"
      assert_content_type(conn, "application/json")

      Plug.Conn.send_resp(conn, 201, ~s({
                                           "name": "#{sname}",
                                           "topic": "#{tname}",
                                           "ackDeadlineSeconds": 10,
                                           "messageRetentionDuration": "#{message_retention}s",
                                           "expirationPolicy": {"ttl": "#{expires_in}s"}
                                        }))
    end)

    assert {:ok,
            %Subscription{
              topic: %Topic{name: ^topic},
              name: ^name,
              ack_deadline: 10,
              expires_in: ^expires_in,
              message_retention_duration: ^message_retention
            }} = Subscription.create(sub)
  end

  test "deleting a subscription", %{bypass: bypass, project: project} do
    name = "delete-me"

    Bypass.expect(bypass, fn conn ->
      assert conn.method == "DELETE"
      assert Regex.match?(~r{projects/#{project}/subscriptions/#{name}}, conn.request_path)
      Plug.Conn.send_resp(conn, 200, "{}\n")
    end)

    Subscription.delete(name)
  end

  test "pulling from a subscription", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"
      assert_content_type(conn, "application/json")
      assert Regex.match?(~r(:pull$), conn.request_path)
      Plug.Conn.send_resp(conn, 200, ~s({"receivedMessages": [
                                          {"ackId":"123",
                                            "message": {
                                              "messageId": "messId",
                                              "publishTime": "2015-10-02T15:01:23.045123456Z",
                                              "attributes": {
                                                "key" : "val"
                                              },
                                              "data": "eyJoZWxsbyI6IndvcmxkIn0="
                                            }
                                          }
                                        ]}))
    end)

    assert {:ok, messages} =
             Subscription.pull(%Subscription{name: "tasty", topic: %Topic{name: "messages"}})

    assert is_list(messages)

    Enum.each(messages, fn m ->
      assert %Message{} = m
    end)
  end

  test "pulling from a subscription passes the correct maxMessages value", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"
      assert_content_type(conn, "application/json")
      assert Regex.match?(~r(:pull$), conn.request_path)

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      data = Jason.decode!(body)
      assert data["maxMessages"] == 2
      assert data["returnImmediately"] == true

      Plug.Conn.send_resp(conn, 200, ~s({"recievedMessages": []}))
    end)

    assert {:ok, []} = Subscription.pull(%Subscription{name: "capped", topic: "sure"}, 2)
  end

  test "pulling from a subscription passes the correct options", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"
      assert_content_type(conn, "application/json")
      assert Regex.match?(~r(:pull$), conn.request_path)

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      data = Jason.decode!(body)
      assert data["maxMessages"] == 5
      assert data["returnImmediately"] == false

      Plug.Conn.send_resp(conn, 200, ~s({"receivedMessages": []}))
    end)

    assert {:ok, []} =
             Subscription.pull(%Subscription{name: "capped", topic: "sure"},
               max_messages: 5,
               return_immediately: false
             )
  end

  test "streaming messages from subscription", %{bypass: bypass} do
    pid = self()

    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"
      assert_content_type(conn, "application/json")
      assert Regex.match?(~r(:pull$), conn.request_path)
      send(pid, :subscription_pull)
      {:ok, _body, conn} = Plug.Conn.read_body(conn)

      Plug.Conn.send_resp(conn, 200, ~s({"receivedMessages": [
                                          {"ackId":"123",
                                            "message": {
                                              "messageId": "messId",
                                              "publishTime": "2015-10-02T15:01:23.045123456Z",
                                              "attributes": {
                                                "key" : "val"
                                              },
                                              "data": "eyJoZWxsbyI6IndvcmxkIn0="
                                            }
                                          },
                                          {"ackId":"456",
                                            "message": {
                                              "messageId": "messId",
                                              "publishTime": "2015-10-02T15:01:23.045123456Z",
                                              "attributes": {
                                                "key" : "val"
                                              },
                                              "data": "eyJoZWxsbyI6IndvcmxkIn0="
                                            }
                                          }
                                        ]}))
    end)

    messages =
      %Subscription{name: "capped", topic: "sure"}
      |> Subscription.stream()
      |> Enum.take(3)

    assert length(messages) == 3

    assert_received :subscription_pull
    assert_received :subscription_pull
    refute_received :subscription_pull
  end

  test "no acknowledgement when no messages given" do
    # This implicitly tests that ByPass does not receive any request
    assert :ok == Subscription.ack(%Subscription{name: "ack-my-sub"}, [])
  end

  test "acknowledging a message", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"
      assert_content_type(conn, "application/json")

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      body = body |> Jason.decode!()
      assert ["123", "321"] = body["ackIds"]

      Plug.Conn.send_resp(conn, 200, "{}\n")
    end)

    messages = [
      %Message{ack_id: "123"},
      %Message{ack_id: "321"}
    ]

    assert :ok == Subscription.ack(%Subscription{name: "ack-my-sub"}, messages)
  end

  test "no-op when no messages are given to extend" do
    # This implicitly tests that ByPass does not receive any request
    assert :ok == Subscription.extend(%Subscription{name: "extend-ack-deadlines"}, [], 600)
  end

  test "extending a message ack deadline", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"
      assert_content_type(conn, "application/json")

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      body = body |> Jason.decode!()
      assert ["123", "321"] = body["ackIds"]
      assert 600 = body["ackDeadlineSeconds"]

      Plug.Conn.send_resp(conn, 200, "{}\n")
    end)

    messages = [
      %Message{ack_id: "123"},
      %Message{ack_id: "321"}
    ]

    assert :ok == Subscription.extend(%Subscription{name: "extend-ack-deadlines"}, messages, 600)
  end

  defp assert_content_type(conn, type) do
    {"content-type", content_type} =
      Enum.find(conn.req_headers, fn {prop, _} ->
        prop == "content-type"
      end)

    assert String.contains?(content_type, type)
  end

  defp to_seconds(milliseconds), do: div(milliseconds, 1000)
end
