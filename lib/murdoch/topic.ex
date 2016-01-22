defmodule Murdoch.Topic do
  defstruct [:name]
  alias Murdoch.Client

  def find(name) do
    case Client.get(path(name)) do
      {:ok, body, _code} ->
        {:ok, Poison.decode!(body)["name"] |> with_name}
      err -> err
    end
  end

  def all do
    case Client.get(path) do
      {:ok, body, _code} ->
        {:ok, %{"topics" => topics}} = Poison.decode(body)
        {:ok, (Enum.map topics, fn(t) ->
          with_name(t["name"])
        end)}
      err -> err
    end
  end

  def create(%__MODULE__{name: topic}), do: create(topic)
  def create(topic) do
    case Client.put(path(topic)) do
      {:ok, _body, _code} -> {:ok, %__MODULE__{name: topic}}
      err -> err
    end
  end

  def delete(%__MODULE__{name: topic}), do: delete(topic)
  def delete(topic), do: Client.delete(path(topic))

  defp with_name(name), do: %__MODULE__{name: String.replace(name, "#{path}/", "")}

  defp project do
    {:ok, project} = Goth.Config.get(:project_id)
    project
  end

  defp path, do: "projects/#{project}/topics"
  defp path(topic), do: "#{path}/#{topic}"
end
