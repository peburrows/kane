defmodule Kane.Topic do
  @moduledoc """
  A `Kane.Topic` is used to interact with and create a topic within the Pub/Sub API.

  Setting up and pulling from a subscription is straightforward:

      # for the most part, names can be include the project prefix or not
      {:ok, subscription} = Kane.Subscription{topic: %Kane.Topic{name: "my-topic"}}
      {:ok, messages} = Kane.Subscription.pull(subscription)
      Enum.each messages, fn(mess)->
        process_message(mess)
      end

      # acknowledge message receipt in bulk
      Kane.Subscription.ack(subscription, messages)
  """
  alias Kane.Client

  @type t :: %__MODULE__{name: String.t()}
  @enforce_keys [:name]
  defstruct [:name]

  @doc """
  Find a topic by name. The name can be either a short name (`my-topic`)
  or the fully-qualified name (`projects/my-project/topics/my-topic`)
  """
  @spec find(Kane.t(), project_id :: String.t()) :: {:ok, t} | Client.error()
  def find(%Kane{project_id: project_id} = kane, topic_name) when is_binary(topic_name) do
    path = topic_path(project_id, topic_name)

    case Client.get(kane, path) do
      {:ok, body, _code} ->
        topic_name = body |> Jason.decode!() |> Map.get("name")
        topic = %__MODULE__{name: strip!(project_id, topic_name)}

        {:ok, topic}

      err ->
        err
    end
  end

  @doc """
  Retrieve all the topics from the API. **NOTE:** `Subscription.all/0` doesn't currently support pagination,
  so if you have more than 100 topics, you won't be able to retrieve all of them.
  """
  @spec all(Kane.t()) :: {:ok, [t()]} | Client.error()
  def all(%Kane{project_id: project_id} = kane) do
    path = topics_project_path(project_id)

    case Client.get(kane, path) do
      {:ok, body, _code} ->
        decoded_topics =
          body
          |> Jason.decode!()
          |> Map.fetch!("topics")
          |> Enum.map(fn json_topic ->
            topic_name = Map.fetch!(json_topic, "name")
            %__MODULE__{name: strip!(project_id, topic_name)}
          end)

        {:ok, decoded_topics}

      err ->
        err
    end
  end

  @doc """
  Create a new topic in the API.
  """
  @spec create(Kane.t(), topic :: t() | String.t()) ::
          {:ok, t} | {:error, :already_exists} | Client.error()
  def create(kane, %__MODULE__{name: topic_name}), do: create(kane, topic_name)

  def create(%Kane{project_id: project_id} = kane, topic_name) when is_binary(topic_name) do
    path = topic_path(project_id, topic_name)

    case Client.put(kane, path) do
      {:ok, _body, _code} -> {:ok, %__MODULE__{name: topic_name}}
      {:error, _body, 409} -> {:error, :already_exists}
      err -> err
    end
  end

  @spec delete(Kane.t(), topic :: t() | String.t()) :: Client.success() | Client.error()
  def delete(kane, %__MODULE__{name: topic_name}), do: delete(kane, topic_name)

  def delete(%Kane{project_id: project_id} = kane, topic_name)
      when is_binary(topic_name) do
    path = topic_path(project_id, topic_name)

    Client.delete(kane, path)
  end

  @doc """
  Strips the project and topic prefix from a fully qualified topic name

      iex> Kane.Topic.strip!("my-project", "projects/my-project/topics/my-topic")
      "my-topic"
  """
  @spec strip!(project_id :: String.t(), topic_name :: String.t()) :: String.t()
  def strip!(project_id, topic_name) do
    path = topics_project_path(project_id)
    String.replace(topic_name, ~r(^#{path}/?), "")
  end

  @doc """
  Adds the project and topic prefix (if necessary) to create a fully-qualified topic name

      iex> Kane.Topic.full_name(%Kane.Topic{name: "my-topic"}, "my-project")
      "projects/my-project/topics/my-topic"
  """
  @spec full_name(t(), project_id :: String.t()) :: String.t()
  def full_name(%__MODULE__{name: name}, project_id), do: full_name(name, project_id)

  def full_name(topic_name, project_id) when is_binary(project_id) and is_binary(topic_name),
    do: topic_path(project_id, topic_name)

  defp topics_project_path(project_id), do: "projects/#{project_id}/topics"

  defp topic_path(project_id, topic),
    do: "#{topics_project_path(project_id)}/#{strip!(project_id, topic)}"
end
