defmodule Kane.SubscriptionTest do
  use ExUnit.Case, async: true

  alias Kane.GCPTestCredentials
  alias Kane.Message
  alias Kane.Subscription
  alias Kane.TestToken
  alias Kane.Topic

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

  describe "find/2" do
    test "finding a subscription", %{kane: kane, bypass: bypass} do
      project_id = kane.project_id
      name = "found-sub"
      topic = "found-sub-topic"

      Bypass.expect(bypass, fn conn ->
        assert conn.method == "GET"
        assert Regex.match?(~r{projects/#{project_id}/subscriptions/#{name}}, conn.request_path)

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
              }} = Subscription.find(kane, name)
    end
  end

  describe "create/2" do
    test "creating a subscription", %{kane: kane, bypass: bypass} do
      project_id = kane.project_id
      name = "create-sub"
      topic = "topic-to-sub"
      sub = %Subscription{name: name, topic: %Topic{name: topic}}

      sname = Subscription.full_name(sub, project_id)
      tname = Topic.full_name(sub.topic, project_id)

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
               Subscription.create(kane, sub)
    end

    test "creating a subscription with filter includes a filter in the request body", %{
      bypass: bypass,
      kane: kane
    } do
      project_id = kane.project_id
      name = "create-sub"
      topic = "topic-to-sub"
      filter = "attributes:domain"

      sub = %Subscription{name: name, topic: %Topic{name: topic}, filter: filter}

      sname = Subscription.full_name(sub, project_id)
      tname = Topic.full_name(sub.topic, project_id)

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
              }} = Subscription.create(kane, sub)
    end
  end

  describe "delete/2" do
    test "deleting a subscription", %{kane: kane, bypass: bypass} do
      project_id = kane.project_id
      name = "delete-me"

      Bypass.expect(bypass, fn conn ->
        assert conn.method == "DELETE"
        assert Regex.match?(~r{projects/#{project_id}/subscriptions/#{name}}, conn.request_path)
        Plug.Conn.send_resp(conn, 200, "{}\n")
      end)

      Subscription.delete(kane, name)
    end
  end

  describe "pull/2" do
    test "pulling from a subscription", %{kane: kane, bypass: bypass} do
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
               Subscription.pull(kane, %Subscription{
                 name: "tasty",
                 topic: %Topic{name: "messages"}
               })

      assert is_list(messages)

      Enum.each(messages, fn m ->
        assert %Message{} = m
      end)
    end

    test "pulling from a subscription passes the correct maxMessages value", %{
      bypass: bypass,
      kane: kane
    } do
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

      assert {:ok, []} = Subscription.pull(kane, %Subscription{name: "capped", topic: "sure"}, 2)
    end

    test "pulling from a subscription passes the correct options", %{kane: kane, bypass: bypass} do
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
               Subscription.pull(kane, %Subscription{name: "capped", topic: "sure"},
                 max_messages: 5,
                 return_immediately: false
               )
    end
  end

  describe "stream/2" do
    test "streaming messages from subscription", %{kane: kane, bypass: bypass} do
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

      subscription = %Subscription{name: "capped", topic: "sure"}

      messages =
        kane
        |> Subscription.stream(subscription)
        |> Enum.take(3)

      assert length(messages) == 3

      assert_received :subscription_pull
      assert_received :subscription_pull
      refute_received :subscription_pull
    end
  end

  describe "ack/2" do
    test "no acknowledgement when no messages given", %{kane: kane} do
      # This implicitly tests that ByPass does not receive any request
      assert :ok == Subscription.ack(kane, %Subscription{name: "ack-my-sub"}, [])
    end

    test "acknowledging a message", %{kane: kane, bypass: bypass} do
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

      assert :ok == Subscription.ack(kane, %Subscription{name: "ack-my-sub"}, messages)
    end
  end

  describe "extend/4" do
    test "no-op when no messages are given to extend", %{kane: kane} do
      # This implicitly tests that ByPass does not receive any request
      assert :ok ==
               Subscription.extend(kane, %Subscription{name: "extend-ack-deadlines"}, [], 600)
    end

    test "extending a message ack deadline", %{kane: kane, bypass: bypass} do
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

      assert :ok ==
               Subscription.extend(
                 kane,
                 %Subscription{name: "extend-ack-deadlines"},
                 messages,
                 600
               )
    end
  end

  defp assert_content_type(conn, type) do
    {"content-type", content_type} =
      Enum.find(conn.req_headers, fn {prop, _} ->
        prop == "content-type"
      end)

    assert String.contains?(content_type, type)
  end
end
