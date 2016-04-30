defmodule Kane.Message do
  alias Kane.Topic
  alias Kane.Client.Response.Error

  @moduledoc """
  `Kane.Message` provides an interface for publishing messaages to a topic.
  A `%Kane.Message{}` struct's `data` can be any type that can be serialized
  to JSON via `Poison.encode/1`. You can also add optional attributes to a
  message, all of whose values must be strings (a restriction of the Pub/Sub API).

  ```
  %Kane.Message{
    data:       "Any serializable type. This could be a map or list or whatever",
    attributes: %{map: "of", key: "and", string: "values"}
  }
  ```
  """

  @type t :: %__MODULE__{
    id: String.t,
    attributes: Map.t,
    data: any,
    ack_id: String.t,
    publish_time: String.t
  }

  defstruct id: nil, attributes: %{}, data: nil, ack_id: nil, publish_time: nil

  @doc """
  Publish a message or a list of messages. When publishing a single message, the
  message can be either a `%Kane.Message{}` or the data you wish to use as the
  message data. When publishing a list of messages, each item in the list must be
  a `%Kane.Message{}`.

  Kane will serialize the message to JSON and encode the message to base64 for you
  before publishing, as per the Pub/Sub spec.

  ```
  %Kane.Message{data: "my message"} |> Kane.Message.publish(%Topic{name: "messages"})
  ```
  """
  @spec publish(binary, binary) :: {:ok, t} | Error.t
  def publish(message, topic) when is_binary(message) and is_binary(topic) do
    publish(%__MODULE__{data: message}, %Topic{name: topic})
  end

  @spec publish(t, Topic.t) :: {:ok, t} | Error.t
  def publish(%__MODULE__{}=message, %Topic{}=topic) do
    case publish([message], topic) do
      {:ok, [message|_]} -> {:ok, message}
      err -> err
    end
  end

  @spec publish([t], Topic.t) :: {:ok, [t]} | Error.t
  def publish(messages, %Topic{name: topic}) when is_list(messages)  do
    case Kane.Client.post(path(topic), data(messages)) do
      {:ok, body, _code} ->
        collected = body
        |> Poison.decode!
        |> Map.get("messageIds")
        |> Stream.with_index
        |> Enum.map(fn({id, i}) ->
             %{Enum.at(messages, i) | id: id}
           end)

        {:ok, collected}
      err -> err
    end
  end

  @doc false
  @spec data([t]) :: map
  def data(%__MODULE__{}=message), do: data([message])
  def data(messages) when is_list(messages) do
    %{
      "messages" =>
        Enum.map(messages, fn(%__MODULE__{data: d, attributes: a}) ->
          %{
            "data" => encode_body(d),
            "attributes" => Enum.reduce(a, %{}, fn({key, val}, map)->
              Map.put(map, key, val)
            end)
          }
        end)
    }
  end

  @doc false
  @spec encode_body(any) :: binary
  def encode_body(body) when is_binary(body), do: Base.encode64(body)
  def encode_body(body), do: body |> Poison.encode! |> encode_body

  @doc false
  def json(%__MODULE__{}=message), do: json([message])
  def json(messages) when is_list(messages) do
    data(messages) |> Poison.encode!
  end

  @doc false
  def from_subscription!(%{}=data) do
    {:ok, message} = from_subscription(data)
    message
  end

  @doc false
  def from_subscription(%{"ackId" => ack, "message" => %{"data" => data, "publishTime" => time, "messageId" => id}}=mess) do
    attr = Map.get(mess, "attributes", %{})
    {:ok, %__MODULE__{
      id: id,
      publish_time: time,
      ack_id: ack,
      data: data |> Base.decode64!,
      attributes: attr
    }}
  end

  defp path(%Topic{name: topic}), do: path(topic)
  defp path(topic) do
    {:ok, project} = Goth.Config.get(:project_id)
    "projects/#{project}/topics/#{Topic.strip!(topic)}:publish"
  end
end
