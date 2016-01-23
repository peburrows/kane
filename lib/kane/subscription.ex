defmodule Kane.Subscription do
  defstruct name: nil, topic: nil, ack_deadline: 10
  alias Kane.Topic

  def create!(%__MODULE__{}=sub) do
    case Kane.Client.put(path(sub, :create), data(sub, :create)) do
      {:ok, _body, _code} -> {:ok, sub}
      {:error, _body, 409} -> {:error, :already_exists}
      err -> err
    end
  end

  def data(%__MODULE__{ack_deadline: ack, topic: %Topic{}=topic}, :create) do
    %{ "topic" => Topic.full_name(topic), "ackDeadlineSeconds" => ack }
  end

  def path(%__MODULE__{}=sub, kind) do
    case kind do
      :pull -> full_name(sub) <> ":pull"
      :ack  -> full_name(sub) <> ":acknowledge"
      _     -> full_name(sub)
    end
  end

  def full_name(%__MODULE__{name: name}) do
    {:ok, project} = Goth.Config.get(:project_id)
    "projects/#{project}/subscriptions/#{name}"
  end
end
