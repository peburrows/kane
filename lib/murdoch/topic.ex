defmodule Murdoch.Topic do
  defstruct [:name]

  def create(%__MODULE__{name: topic}), do: create(topic)
  def create(topic) do
    {:ok, project} = Goth.Config.get(:project_id)
    case Murdoch.Client.put("projects/#{project}/topics/#{topic}") do
      {:ok, _body, _code} -> {:ok, %__MODULE__{name: topic}}
      err -> err
    end
  end
end
