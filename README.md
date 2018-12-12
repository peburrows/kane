[![Build Status](https://travis-ci.org/peburrows/kane.svg?branch=master)](https://travis-ci.org/peburrows/kane)

# Kane

Kane. Citizen Kane. Charles Foster Kane, to be exact, Publisher extraordinaire. Rosebud.

Kane is for publishing and subscribing to topics using Google Cloud Pub/Sub.

## Installation

1. Add Kane to your list of dependencies in `mix.exs`:
  ```elixir
  def deps do
    [{:kane, "~> 0.2.0"}]
  end
  ```

2. Configure [Goth](https://github.com/peburrows/goth) (Kane's underlying token storage and retrieval library) with your Google JSON credentials:
  ```elixir
  config :goth,
    json: "path/to/google/json/creds.json" |> File.read!
  ```

3. Ensure Kane is started before your application:
  ```elixir
  def application do
    [applications: [:kane]]
  end
  ```


## Usage

Pull, process and acknowledge messages via a pre-existing subscription:

```elixir
subscription = %Kane.Subscription{
  name: "project-name",
  topic: %Kane.Topic{name: "my-topic"}
}
{:ok, messages} = Kane.Subscription.pull(subscription)

Enum.each messages, fn(mess)->
  process_message(mess)
end

# acknowledge message receipt in bulk
Kane.Subscription.ack(subscription, messages)
```

Send message via pre-existing subscription:
```elixir
topic   = %Kane.Topic{name: "my-topic"}
message = %Kane.Message{data: %{"hello": "world"}, attributes: %{"random" => "attr"}}

result  = Kane.Message.publish(message, topic)

case result do 
  {:ok, _return}    -> IO.puts("It worked!")
  {:error, _reason} -> IO.puts("Should we try again?")
end
```
Hints: 
- Attributes have to be Strings (https://cloud.google.com/pubsub/docs/reference/rest/v1/PubsubMessage)
- We base64-encode the message by default (only mandatory when using json - https://cloud.google.com/pubsub/publisher)

For more details, see the [documentation](http://hexdocs.pm/kane).
