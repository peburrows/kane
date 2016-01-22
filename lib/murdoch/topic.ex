defmodule Murdoch.Topic do
  defstruct [:name]

  def create(%__MODULE__{name: topic}), do: create(topic)
  def create(topic) do
    case Murdoch.Client.put(path(topic)) do
      {:ok, _body, _code} -> {:ok, %__MODULE__{name: topic}}
      err -> err
    end
  end

  def delete(%__MODULE__{name: topic}), do: delete(topic)
  def delete(topic), do: Murdoch.Client.delete(path(topic))

  defp project do
    {:ok, project} = Goth.Config.get(:project_id)
    project
  end

  defp path(topic), do: "projects/#{project}/topics/#{topic}"
end
