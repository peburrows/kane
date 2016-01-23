defmodule Kane.Message do
  alias Kane.Topic
  defstruct id: nil, attributes: %{}, data: nil

  def publish(%__MODULE__{}=message, %Topic{}=topic), do: publish([message], topic)
  def publish(messages, %Topic{name: topic}) when is_list(messages)  do
    case Kane.Client.post(path(topic), data(messages)) do
      {:ok, body, _code} ->
        ids = body
              |> Poison.decode!
              |> Map.get("messageIds")
        collected = for id <- ids, message <- messages do
          %{message | id: id}
        end
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
            "data" => (d |> Poison.encode! |> Base.encode64),
            "attributes" => Enum.reduce(a, %{}, fn({key, val}, map)->
              Map.put(map, key, val)
            end)
          }
        end)
    }
  end

  def json(%__MODULE__{}=message), do: json([message])
  def json(messages) when is_list(messages) do
    data(messages) |> Poison.encode!
  end

  defp path(%Topic{name: topic}), do: path(topic)
  defp path(topic) do
    {:ok, project} = Goth.Config.get(:project_id)
    "projects/#{project}/topics/#{Topic.strip!(topic)}:publish"
  end
end
