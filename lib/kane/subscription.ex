defmodule Kane.Subscription do
  defstruct name: nil, topic: nil, ack_deadline: 10
  alias Kane.Topic
  alias Kane.Message
  alias Kane.Client

  @type s :: %__MODULE__{name: binary}

  def create(%__MODULE__{}=sub) do
    case Kane.Client.put(path(sub, :create), data(sub, :create)) do
      {:ok, _body, _code} -> {:ok, sub}
      {:error, _body, 409} -> {:error, :already_exists}
      err -> err
    end
  end

  @doc """
  Find a subscription by name. The name can be either a short name
  (`my-subscription`) or the fully-qualified name
  (`projects/my-project/subscriptions/my-subscription`).
  """
  @spec find(String.s) :: {:ok, s} | Error.s
  def find(name) do
    case Client.get(find_path(name)) do
      {:ok, body, _code} ->
        {:ok, from_json(body)}
      err -> err
    end
  end

  def delete(%__MODULE__{name: name}), do: delete(name)
  def delete(name), do: Kane.Client.delete(path(name, :delete))

  def pull(%__MODULE__{}=sub, maxMessages \\ 100) do
    case Kane.Client.post(path(sub, :pull), data(sub, :pull, maxMessages)) do
      {:ok, body, _code} when body in ["{}", "{}\n"] ->
        {:ok, []}
      {:ok, body, _code} ->
        {:ok, body
              |> Poison.decode!
              |> Map.get("receivedMessages", [])
              |> Enum.map(fn(m) ->
                  Message.from_subscription!(m)
                end)
              }
      err -> err
    end
  end

  def ack(%__MODULE__{}=sub, messages) when is_list(messages) do
    data = %{"ackIds" => Enum.map(messages, fn(m)-> m.ack_id end)}
    case Kane.Client.post(path(sub, :ack), data) do
      {:ok, _body, _code} -> :ok
      err -> err
    end
  end
  def ack(%__MODULE__{}=sub, %Message{}=mess), do: ack(sub, [mess])

  def data(%__MODULE__{ack_deadline: ack, topic: %Topic{}=topic}, :create) do
    %{"topic" => Topic.full_name(topic), "ackDeadlineSeconds" => ack}
  end

  def data(%__MODULE__{}, :pull, max) do
    %{
      "returnImmediately" => true,
      "maxMessages" => max,
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
      :ack  -> full_name(name) <> ":acknowledge"
      _     -> full_name(name)
    end
  end

  def full_name(%__MODULE__{name: name}), do: full_name(name)
  def full_name(name) do
    {:ok, project} = Goth.Config.get(:project_id)
    "projects/#{project}/subscriptions/#{name}"
  end

  def strip!(name), do: String.replace(name, ~r(^#{find_path()}/?), "")

  defp from_json(json) do
    data = Poison.decode!(json)
    %__MODULE__{
      name: Map.get(data, "name"),
      ack_deadline: Map.get(data, "ackDeadlineSeconds"),
      topic: %Topic{name: Map.get(data, "topic")}
    }
  end
end
