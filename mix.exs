defmodule Kane.Mixfile do
  use Mix.Project

  def project do
    [
      app: :kane,
      version: "1.0.0",
      elixir: "~> 1.4",
      package: package(),
      description: description(),
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:goth, "~> 1.3"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.1"},
      {:bypass, "~> 2.0", only: :test},
      {:mix_test_watch, "~> 0.4", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev},
      {:uuid, "~> 1.1", only: :test}
    ]
  end

  defp description do
    """
    A library for interacting with Google Cloud Pub/Sub (PubSub).
    Supports both publication and pull subscription
    """
  end

  defp package do
    [
      maintainers: ["Phil Burrows"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/peburrows/kane"}
    ]
  end
end
