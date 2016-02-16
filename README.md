# Kane

Kane. Citizen Kane. Charles Foster Kane, to be exact, Publisher extraordinaire. Rosebud.

Kane is for publishing and subscribing to topics using Google Cloud Pub/Sub.

## Installation

1. Add Kane to your list of dependencies in `mix.exs`:
  ```elixir
  def deps do
    [{:kane, "~> 0.0.5"}]
  end
  ```

2. Configure [Goth](https://github.com/peburrows/goth) (Kane's underlying token storage and retrieval library) with your Google JSON credentials:
  ```elixir
  config :goth,
    json: "path/to/google/json/creds.json" |> File.read!
  ```


## Usage

See [documentation](http://hexdocs.pm/kane) for usage.
