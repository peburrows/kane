defmodule Kane.Subscription do
  defstruct name: nil, topic: nil, ack_deadline: 10, filter: nil
  alias Kane.Topic
  alias Kane.Message
  alias Kane.Client

  @type s :: %__MODULE__{name: binary}

  def create(%__MODULE__{} = sub) do
    case Kane.Client.put(path(sub, :create), data(sub, :create)) do
      {:ok, body, _code} -> {:ok, from_json(body)}
      {:error, _body, 409} -> {:error, :already_exists}
      err -> err
    end
  end

  @doc """
  Find a subscription by name. The name can be either a short name (`my-subscription`)
  or the fully-qualified name (`projects/my-project/subscriptions/my-subscription`)
  """
  @spec find(String.s()) :: {:ok, s} | Error.s()
  def find(name) do
    case Client.get(find_path(name)) do
      {:ok, body, _code} ->
        {:ok, from_json(body)}

      err ->
        err
    end
  end

  def delete(%__MODULE__{name: name}), do: delete(name)
  def delete(name), do: Kane.Client.delete(path(name, :delete))

  def pull(sub, options \\ [])

  def pull(%__MODULE__{} = sub, max_messages) when is_integer(max_messages) do
    pull(sub, max_messages: max_messages)
  end

  def pull(%__MODULE__{} = sub, options) do
    case Kane.Client.post(
           path(sub, :pull),
           data(sub, :pull, options),
           http_options(options)
         ) do
      {:ok, body, _code} when body in ["{}", "{}\n"] ->
        {:ok, []}

      {:ok, body, _code} ->
        {:ok,
         body
         |> Jason.decode!()
         |> Map.get("receivedMessages", [])
         |> Enum.map(fn m ->
           Message.from_subscription!(m)
         end)}

      err ->
        err
    end
  end

  def stream(%__MODULE__{} = sub, options \\ []) do
    options = Keyword.put(options, :return_immediately, false)

    Stream.resource(
      fn -> :ok end,
      fn acc ->
        case pull(sub, options) do
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

  def ack(%__MODULE__{}, []), do: :ok

  def ack(%__MODULE__{} = sub, messages) when is_list(messages) do
    data = %{"ackIds" => Enum.map(messages, fn m -> m.ack_id end)}

    case Kane.Client.post(path(sub, :ack), data) do
      {:ok, _body, _code} -> :ok
      err -> err
    end
  end

  def ack(%__MODULE__{} = sub, %Message{} = mess), do: ack(sub, [mess])

  def extend(%__MODULE__{}, [], _), do: :ok

  def extend(%__MODULE__{} = sub, %Message{} = msg, extension), do: extend(sub, [msg], extension)

  def extend(%__MODULE__{} = sub, messages, extension)
      when is_list(messages) and is_integer(extension) do
    data = %{
      "ackIds" => Enum.map(messages, & &1.ack_id),
      "ackDeadlineSeconds" => extension
    }

    case Kane.Client.post(path(sub, :extend), data) do
      {:ok, _body, _code} -> :ok
      err -> err
    end
  end

  def data(%__MODULE__{ack_deadline: ack, topic: %Topic{} = topic, filter: nil}, :create) do
    %{
      "topic" => Topic.full_name(topic),
      "ackDeadlineSeconds" => ack
    }
  end

  def data(%__MODULE__{ack_deadline: ack, topic: %Topic{} = topic, filter: filter}, :create) do
    %{
      "topic" => Topic.full_name(topic),
      "ackDeadlineSeconds" => ack,
      "filter" => filter
    }
  end

  def data(%__MODULE__{}, :pull, options) do
    %{
      returnImmediately: Keyword.get(options, :return_immediately, true),
      maxMessages: Keyword.get(options, :max_messages, 100)
    }
  end

  defp project do
    {:ok, project} = Goth.Config.get(:project_id)
    project
  end

  defp find_path, do: "projects/#{project()}/subscriptions"
  defp find_path(subscription), do: "#{find_path()}/#{strip!(subscription)}"

  def path(%__MODULE__{name: name}, kind), do: path(name, kind)

  def path(name, kind) do
    case kind do
      :pull -> full_name(name) <> ":pull"
      :ack -> full_name(name) <> ":acknowledge"
      :extend -> full_name(name) <> ":modifyAckDeadline"
      _ -> full_name(name)
    end
  end

  def full_name(%__MODULE__{name: name}), do: full_name(name)

  def full_name(name) do
    {:ok, project} = Goth.Config.get(:project_id)
    "projects/#{project}/subscriptions/#{name}"
  end

  def strip!(name), do: String.replace(name, ~r(^#{find_path()}/?), "")

  defp from_json(json) do
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
      name: strip!(subscription_name),
      ack_deadline: Map.get(data, "ackDeadlineSeconds"),
      topic: %Topic{name: Topic.strip!(topic_name)},
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
