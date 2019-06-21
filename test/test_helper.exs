ExUnit.start()
Application.ensure_all_started(:bypass)

defmodule Kane.TestToken do
  def for_scope(scope) do
    {:ok,
     %Gotham.Token{
       access_token: UUID.uuid1(),
       account_name: :account1,
       expire_at: :os.system_time(:seconds) + 3600,
       project_id: "pxn-staging-env",
       scope: scope,
       token_type: "Bearer"
     }}
  end
end
