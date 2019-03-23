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
  alias Kane.Client.Response.Error

  @type t :: %__MODULE__{name: binary}
  defstruct [:name]

  @doc """
  Find a topic by name. The name can be either a short name (`my-topic`)
  or the fully-qualified name (`projects/my-project/topics/my-topic`)
  """
  @spec find(String.t()) :: {:ok, t} | Error.t()
  def find(name) do
    case Client.get(path(name)) do
      {:ok, body, _code} ->
        {:ok, body |> Jason.decode!() |> Map.get("name") |> with_name}

      err ->
        err
    end
  end

  @doc """
  Retrieve all the topics from the API. **NOTE:** `Subscription.all/0` doesn't currently support pagination,
  so if you have more than 100 topics, you won't be able to retrieve all of them.
  """
  @spec all :: {:ok, [t]} | Error.t()
  def all do
    case Client.get(path()) do
      {:ok, body, _code} ->
        {:ok, %{"topics" => topics}} = Jason.decode(body)

        {:ok,
         Enum.map(topics, fn t ->
           with_name(t["name"])
         end)}

      err ->
        err
    end
  end

  @doc """
  Create a new topic in the API
  """
  @spec create(t | String.t()) :: {:ok, t} | {:error, :already_exists} | Error.t()
  def create(%__MODULE__{name: topic}), do: create(topic)

  def create(topic) do
    case Client.put(path(topic)) do
      {:ok, _body, _code} -> {:ok, %__MODULE__{name: topic}}
      {:error, _body, 409} -> {:error, :already_exists}
      err -> err
    end
  end

  @spec delete(t | String.t()) :: {:ok, String.t(), non_neg_integer} | Error.t()
  def delete(%__MODULE__{name: topic}), do: delete(topic)
  def delete(topic), do: Client.delete(path(topic))

  @doc """
  Strips the project and topic prefix from a fully qualified topic name

      iex> Kane.Topic.strip!("projects/my-project/topics/my-topic")
      "my-topic"
  """
  @spec strip!(String.t()) :: String.t()
  def strip!(name), do: String.replace(name, ~r(^#{path()}/?), "")

  @doc """
  Adds the project and topic prefix (if necessary) to create a fully-qualified topic name

      iex> Kane.Topic.full_name(%Kane.Topic{name: "my-topic"})
      "projects/my-project/topics/my-topic"
  """
  @spec full_name(t) :: String.t()
  def full_name(%__MODULE__{name: name}), do: path(name)
  def full_name(name), do: full_name(%__MODULE__{name: name})

  defp with_name(name), do: %__MODULE__{name: strip!(name)}

  defp project do
    {:ok, id} = Goth.Config.get(:project_id)
    id
  end

  defp path, do: "projects/#{project()}/topics"
  defp path(topic), do: "#{path()}/#{strip!(topic)}"
end
