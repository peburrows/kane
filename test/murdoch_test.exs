defmodule MurdochTest do
  use ExUnit.Case
  doctest Murdoch

  test "publishing" do
    # {:ok, topic} = Murdoch.Topic.create()
    # Murdoch.publish(topic, %{})
    # or, should it accept a token?
    # Murdoch.subscribe(topic, token)
    # Murdoch.subscribe(topic)
    # 1) retrieves a token
    # 2) creates a subscription
  end
end
