defmodule Kane.Subscription do
  defstruct name: nil, topic: nil, ack_deadline: 10, filter: nil

  alias Kane.Topic
  alias Kane.Message
  alias Kane.Client

  @type t :: %__MODULE__{name: String.t()}

  @spec create(Kane.t(), t()) :: {:ok, t()} | {:error, :already_exists} | Client.error()
  def create(%Kane{project_id: project_id} = kane, %__MODULE__{} = sub) do
    path = create_subscription_path(project_id, sub)
    data = create_data(project_id, sub)

    case Kane.Client.put(kane, path, data) do
      {:ok, body, _code} -> {:ok, from_json(project_id, body)}
      {:error, _body, 409} -> {:error, :already_exists}
      err -> err
    end
  end

  defp create_subscription_path(project_id, subscription), do: full_name(subscription, project_id)

  defp create_data(project_id, %__MODULE__{
         ack_deadline: ack,
         topic: %Topic{} = topic,
         filter: nil
       }) do
    %{
      "topic" => Topic.full_name(topic, project_id),
      "ackDeadlineSeconds" => ack
    }
  end

  defp create_data(project_id, %__MODULE__{
         ack_deadline: ack,
         topic: %Topic{} = topic,
         filter: filter
       }) do
    %{
      "topic" => Topic.full_name(topic, project_id),
      "ackDeadlineSeconds" => ack,
      "filter" => filter
    }
  end

  @doc """
  Find a subscription by name. The name can be either a short name (`my-subscription`)
  or the fully-qualified name (`projects/my-project/subscriptions/my-subscription`)
  """
  @spec find(Kane.t(), String.t()) :: {:ok, t()} | Client.error()
  def find(%Kane{project_id: project_id} = kane, name) when is_binary(name) do
    path = find_subscription_path(project_id, name)

    case Client.get(kane, path) do
      {:ok, body, _code} ->
        {:ok, from_json(project_id, body)}

      err ->
        err
    end
  end

  defp find_subscription_path(project_id, sub_name) do
    sub_name = strip!(project_id, sub_name)
    full_name(sub_name, project_id)
  end

  @spec delete(kane :: Kane.t(), subscription :: t() | String.t()) ::
          Client.success() | Client.error()
  def delete(kane, %__MODULE__{name: sub_name}), do: delete(kane, sub_name)

  def delete(%Kane{project_id: project_id} = kane, sub_name) do
    path = delete_subscription_path(project_id, sub_name)

    Client.delete(kane, path)
  end

  defp delete_subscription_path(project_id, subscription), do: full_name(subscription, project_id)

  @spec pull(Kane.t(), t(), Keyword.t() | pos_integer()) :: {:ok, [Message.t()]} | Client.error()
  def pull(kane, sub, options \\ [])

  def pull(kane, %__MODULE__{} = sub, max_messages) when is_integer(max_messages) do
    pull(kane, sub, max_messages: max_messages)
  end

  def pull(%Kane{project_id: project_id} = kane, %__MODULE__{} = sub, options) do
    path = pull_subscriptions_messages_path(project_id, sub)
    data = pull_data(sub, options)
    http_options = http_options(options)

    case Kane.Client.post(kane, path, data, http_options) do
      {:ok, body, _code} when body in ["{}", "{}\n"] ->
        {:ok, []}

      {:ok, body, _code} ->
        messages =
          body
          |> Jason.decode!()
          |> Map.get("receivedMessages", [])
          |> Enum.map(&Message.from_subscription!/1)

        {:ok, messages}

      err ->
        err
    end
  end

  defp pull_subscriptions_messages_path(project_id, subscription) do
    "#{full_name(subscription, project_id)}:pull"
  end

  defp pull_data(%__MODULE__{}, options) do
    %{
      returnImmediately: Keyword.get(options, :return_immediately, true),
      maxMessages: Keyword.get(options, :max_messages, 100)
    }
  end

  @spec stream(Kane.t(), t(), Keyword.t() | pos_integer()) :: Enumerable.t()
  def stream(%Kane{} = kane, %__MODULE__{} = sub, options \\ []) do
    options = Keyword.put(options, :return_immediately, false)

    Stream.resource(
      fn -> :ok end,
      fn acc ->
        case pull(kane, sub, options) do
          {:ok, messages} ->
            {messages, acc}

          err ->
            {:halt, err}
        end
      end,
      fn
        :ok -> nil
        err -> throw(err)
      end
    )
  end

  @spec ack(Kane.t(), t(), messages :: Message.t() | [Message.t()]) :: :ok | Client.error()
  def ack(%Kane{}, %__MODULE__{}, []), do: :ok

  def ack(kane, sub, %Message{} = message), do: ack(kane, sub, [message])

  def ack(%Kane{project_id: project_id} = kane, %__MODULE__{} = sub, messages)
      when is_list(messages) do
    path = ack_subscriptions_message_path(project_id, sub)

    data = %{"ackIds" => Enum.map(messages, fn m -> m.ack_id end)}

    case Kane.Client.post(kane, path, data) do
      {:ok, _body, _code} -> :ok
      err -> err
    end
  end

  defp ack_subscriptions_message_path(project_id, subscription) do
    "#{full_name(subscription, project_id)}:acknowledge"
  end

  @spec extend(Kane.t(), t(), messages :: Message.t() | [Message.t()], extension :: pos_integer()) ::
          :ok | Client.error()
  def extend(%Kane{}, %__MODULE__{}, [], _), do: :ok

  def extend(kane, sub, %Message{} = msg, extension), do: extend(kane, sub, [msg], extension)

  def extend(%Kane{project_id: project_id} = kane, %__MODULE__{} = sub, messages, extension)
      when is_list(messages) and is_integer(extension) do
    path = extend_subscriptions_message_path(project_id, sub)

    data = %{
      "ackIds" => Enum.map(messages, & &1.ack_id),
      "ackDeadlineSeconds" => extension
    }

    case Kane.Client.post(kane, path, data) do
      {:ok, _body, _code} -> :ok
      err -> err
    end
  end

  defp extend_subscriptions_message_path(project_id, subscription) do
    "#{full_name(subscription, project_id)}:modifyAckDeadline"
  end

  @spec full_name(subscription :: t() | String.t(), String.t()) :: String.t()
  def full_name(%__MODULE__{name: sub_name}, project_id), do: full_name(sub_name, project_id)

  def full_name(sub_name, project_id) do
    "#{subscriptions_path(project_id)}/#{sub_name}"
  end

  defp subscriptions_path(project_id), do: "projects/#{project_id}/subscriptions"

  @spec strip!(project_id :: String.t(), name :: String.t()) :: String.t()
  def strip!(project_id, name) do
    String.replace(name, ~r(^#{subscriptions_path(project_id)}/?), "")
  end

  defp from_json(project_id, json) do
    data = Jason.decode!(json)

    subscription_name = Map.get(data, "name")
    topic_name = Map.get(data, "topic")

    # When clients are working with subscriptions, the topic and subscription names aren't
    # fully qualified (ie. they aren't prefixed with the project, topic, etc.) However,
    # we do fully qualify subscription and topic names when creating subscriptions, and
    # the server is going to respond with a fully qualified name.
    #
    # To preserve the behavior where the Subscription always includes just the shortened
    # name, we strip away the prefix for the topic and subscription names at the time we
    # deserialize the response.
    %__MODULE__{
      name: strip!(project_id, subscription_name),
      ack_deadline: Map.get(data, "ackDeadlineSeconds"),
      topic: %Topic{name: Topic.strip!(project_id, topic_name)},
      filter: Map.get(data, "filter")
    }
  end

  defp http_options(options) do
    case Keyword.get(options, :return_immediately, true) do
      false -> [recv_timeout: :infinity]
      _ -> [recv_timeout: 60_000]
    end
  end
end
