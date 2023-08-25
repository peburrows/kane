[![Build Status](https://travis-ci.org/peburrows/kane.svg?branch=master)](https://travis-ci.org/peburrows/kane)

# Kane

Kane. Citizen Kane. Charles Foster Kane, to be exact, Publisher extraordinaire. Rosebud.

Kane is for publishing and subscribing to topics using Google Cloud Pub/Sub.

## Installation

1. Add Kane to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:kane, "~> 1.0"}]
end
```

2. Configure [Goth](https://github.com/peburrows/goth) (Kane's underlying token storage and retrieval library) with your Google JSON credentials.

## Usage

Pull, process and acknowledge messages via a pre-existing subscription:

```elixir
{:ok, token} = Goth.fetch(MyApp.Goth)

kane = %Kane{
  project_id: my_app_gcp_credentials["project_id"],
  token: token
}

subscription = %Kane.Subscription{
                  name: "my-sub",
                  topic: %Kane.Topic{
                    name: "my-topic"
                  }
                }

{:ok, messages} = Kane.Subscription.pull(kane, subscription)

Enum.each messages, fn(mess)->
  process_message(mess)
end

# acknowledge message receipt in bulk
Kane.Subscription.ack(kane, subscription, messages)
```

Send message via pre-existing subscription:

```elixir
topic   = %Kane.Topic{name: "my-topic"}
message = %Kane.Message{data: %{"hello": "world"}, attributes: %{"random" => "attr"}}

result  = Kane.Message.publish(kane, message, topic)

case result do
  {:ok, _return}    -> IO.puts("It worked!")
  {:error, _reason} -> IO.puts("Should we try again?")
end
```

Hints:

- Attributes have to be Strings (https://cloud.google.com/pubsub/docs/reference/rest/v1/PubsubMessage)
- We base64-encode the message by default (only mandatory when using json - https://cloud.google.com/pubsub/publisher)

For more details, see the [documentation](http://hexdocs.pm/kane).
