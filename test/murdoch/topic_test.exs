defmodule Murdoch.TopicTest do
  use ExUnit.Case

  setup do
    bypass = Bypass.open
    Application.put_env(:murdoch, :endpoint, "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass}
  end

  test "creating a topic is successful" do

  end
end
