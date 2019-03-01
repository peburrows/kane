ExUnit.start()
Application.ensure_all_started(:bypass)

defmodule Kane.TestToken do
  def for_scope(scope) do
    {:ok,
     %Goth.Token{
       scope: scope,
       expires: :os.system_time(:seconds) + 3600,
       type: "Bearer",
       token: UUID.uuid1()
     }}
  end
end
