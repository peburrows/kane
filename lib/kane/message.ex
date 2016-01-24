defmodule Kane.Message do
  alias Kane.Topic
  defstruct id: nil, attributes: %{}, data: nil, ack_id: nil, publish_time: nil

  def publish(%__MODULE__{}=message, %Topic{}=topic) do
    case publish([message], topic) do
      {:ok, [message|_]} -> {:ok, message}
      err -> err
    end
  end

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

  def publish(message, topic) when is_binary(message) and is_binary(topic) do
    publish(%__MODULE__{data: message}, %Topic{name: topic})
  end

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

  def encode_body(body) when is_binary(body), do: Base.encode64(body)
  def encode_body(body), do: body |> Poison.encode! |> encode_body

  def json(%__MODULE__{}=message), do: json([message])
  def json(messages) when is_list(messages) do
    data(messages) |> Poison.encode!
  end

  def from_subscription!(%{}=data) do
    {:ok, message} = from_subscription(data)
    message
  end

  def from_subscription(%{"ackId" => ack, "message" => %{"data" => data, "publishTime" => time, "messageId" => id}}=mess) do
    attr = Map.get(mess, "attributes", %{})
    {:ok, %__MODULE__{
      id: id,
      publish_time: time,
      ack_id: ack,
      data: data,
      attributes: attr
    }}
  end

  defp path(%Topic{name: topic}), do: path(topic)
  defp path(topic) do
    {:ok, project} = Goth.Config.get(:project_id)
    "projects/#{project}/topics/#{Topic.strip!(topic)}:publish"
  end
end
