defmodule Kane.Subscription do
  defstruct name: nil, topic: nil, ack_deadline: 10
  alias Kane.Topic
  alias Kane.Message
  alias Kane.Client

  @type s :: %__MODULE__{name: binary}

  def create(%__MODULE__{} = sub) do
    case Kane.Client.put(path(sub, :create), data(sub, :create)) do
      {:ok, _body, _code} -> {:ok, sub}
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

  def data(%__MODULE__{ack_deadline: ack, topic: %Topic{} = topic}, :create) do
    %{"topic" => Topic.full_name(topic), "ackDeadlineSeconds" => ack}
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

  # defp find_path, do: "projects/#{project()}/subscriptions"

  defp find_path({project, sub}), do: "projects/#{project}/subscriptions/#{sub}"

  defp find_path(subscription) do
    subscription
    |> String.contains?("/")
    |> if do
      subscription
    else
      find_path({project(), subscription})
    end
  end

  def path(%__MODULE__{name: name}, kind), do: path(name, kind)

  def path(name, kind) do
    case kind do
      :pull -> full_name(name) <> ":pull"
      :ack -> full_name(name) <> ":acknowledge"
      _ -> full_name(name)
    end
  end

  def full_name(%__MODULE__{name: name}), do: full_name(name)

  def full_name({project, name}), do: "projects/#{project}/subscriptions/#{name}"

  def full_name(name) do
    name
    |> String.contains?("/")
    |> if do
      name
    else
      {:ok, project} = Goth.Config.get(:project_id)
      full_name({project, name})
    end
  end

  def strip!(name) do
    name
    |> String.split("/", trim: true)
    |> List.last()
  end

  defp from_json(json) do
    data = Jason.decode!(json)

    %__MODULE__{
      name: Map.get(data, "name"),
      ack_deadline: Map.get(data, "ackDeadlineSeconds"),
      topic: %Topic{name: Map.get(data, "topic")}
    }
  end

  defp http_options(options) do
    case Keyword.get(options, :return_immediately, true) do
      false -> [recv_timeout: :infinity]
      _ -> []
    end
  end
end
