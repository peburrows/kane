use Mix.Config

config :gotham,
  default_account: :test,
  accounts: [
    {:test, file_path: "config/test-credentials.json"}
  ]

config :kane, :token, Kane.TestToken
