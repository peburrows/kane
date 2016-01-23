defmodule Kane.SubscriptionTest do
  use ExUnit.Case
  alias Kane.Subscription
  alias Kane.Topic

  setup do
    bypass = Bypass.open
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
    topic= "sub-json-topic"
    sub = %Subscription{name: name, topic: %Topic{name: topic}}
    assert %{
        "topic" => "projects/#{project}/topics/#{topic}",
        "ackDeadlineSeconds" => 10
      } == Subscription.data(sub, :create)
  end

  test "creating a subscription", %{bypass: bypass, project: project} do
    name = "create-sub"
    topic= "topic-to-sub"
    sub  = %Subscription{name: name, topic: %Topic{name: topic}}

    Bypass.expect bypass, fn conn ->
      sname = Subscription.full_name(sub)
      tname = Topic.full_name(sub.topic)

      {:ok, body, conn} = Plug.Conn.read_body conn

      assert body == %{"topic" => tname, "ackDeadlineSeconds" => sub.ack_deadline} |> Poison.encode!
      assert conn.method == "PUT"

      Plug.Conn.send_resp conn, 201, ~s({
                                           "name": "#{sname}",
                                           "topic": "#{tname}",
                                           "ackDeadlineSeconds": 10
                                        })
    end

    assert {:ok,
              %Subscription{
                topic: %Topic{name: ^topic},
                name: ^name,
                ack_deadline: 10}
            } = Subscription.create!(sub)
  end
end
