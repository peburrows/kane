defmodule Kane.Message do
  alias Kane.Topic
  alias Kane.Client

  @type message_data :: binary() | Jason.Encoder.t()

  @type t :: %__MODULE__{
          id: String.t() | nil,
          attributes: Map.t(),
          data: message_data(),
          ack_id: String.t() | nil,
          publish_time: String.t() | nil
        }

  defstruct id: nil, attributes: %{}, data: nil, ack_id: nil, publish_time: nil

  @spec publish(
          Kane.t(),
          messages :: message_data() | t() | [t()],
          topic :: String.t() | Topic.t()
        ) :: {:ok, t() | [t()]} | Client.error()
  def publish(kane, message, topic) when is_binary(topic) do
    publish(kane, %__MODULE__{data: message}, %Topic{name: topic})
  end

  def publish(kane, %__MODULE__{} = message, topic) do
    case publish(kane, [message], topic) do
      {:ok, [message]} -> {:ok, message}
      err -> err
    end
  end

  def publish(%Kane{project_id: project_id} = kane, messages, %Topic{name: topic_name})
      when is_list(messages) do
    publish_path = "projects/#{project_id}/topics/#{Topic.strip!(project_id, topic_name)}:publish"
    data = publish_data(messages)

    case Client.post(kane, publish_path, data) do
      {:ok, body, _code} ->
        collected =
          body
          |> Jason.decode!()
          |> Map.get("messageIds")
          |> Enum.zip(messages)
          |> Enum.map(fn {id, message} ->
            %{message | id: id}
          end)

        {:ok, collected}

      err ->
        err
    end
  end

  defp publish_data(messages) do
    %{
      "messages" =>
        Enum.map(messages, fn %__MODULE__{data: d, attributes: a} ->
          %{
            "data" => encode_body(d),
            "attributes" => Map.new(a)
          }
        end)
    }
  end

  defp encode_body(body) when is_binary(body), do: Base.encode64(body)
  defp encode_body(body), do: body |> Jason.encode!() |> encode_body

  @spec from_subscription!(payload :: map()) :: t()
  def from_subscription!(%{
        "ackId" => ack,
        "message" => %{"publishTime" => time, "messageId" => id} = message
      }) do
    attr = Map.get(message, "attributes", %{})

    data =
      case Map.get(message, "data", nil) do
        nil -> nil
        actual_data -> Base.decode64!(actual_data)
      end

    %__MODULE__{
      id: id,
      publish_time: time,
      ack_id: ack,
      data: data,
      attributes: attr
    }
  end
end
