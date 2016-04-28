defmodule Kane.Mixfile do
  use Mix.Project

  def project do
    [app: :kane,
     version: "0.1.0",
     elixir: "~> 1.2",
     package: package,
     description: description,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :goth]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:goth, "~> 0.1.1"},
    {:poison, "~> 1.5 or ~> 2.1"},
    {:httpoison, "~> 0.8.0"},
    {:bypass, "~> 0.1", only: :test},
    {:mix_test_watch, "~> 0.2.5", only: :dev},
    {:ex_doc, "~> 0.11.3", only: [:dev]},
    {:earmark, "~> 0.2", only: [:dev]},
    {:uuid, "~> 1.1", only: :test}]
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
