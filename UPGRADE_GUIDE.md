## Upgrading from Kane 0.9

Earlier versions of Kane relied on global application environment configuration which is deprecated in favour of a more direct and explicit approach in Kane vX.X+. Kane is following the same principle changes of [Goth 1.3+](https://github.com/peburrows/goth/blob/master/UPGRADE_GUIDE.md).

Below is a step-by-step upgrade path from Goth 0.x to X.X:

Upgrade Goth to [1.3+](https://github.com/peburrows/goth/blob/master/UPGRADE_GUIDE.md). Previous versions of Kane, heavily depended on the global configuration of Goth.

So, your `mix.exs` should be looking like this:

```elixir
def deps do
  [
    {:goth, "~> 1.3"},
    {:kane, "~> X.X"}
  ]
end
```

You might have a code similar to this:


```elixir
subscription = %Kane.Subscription{
                  name: "my-sub",
                  topic: %Kane.Topic{
                    name: "my-topic"
                  }
                }

{:ok, messages} = Kane.Subscription.pull(subscription)
```

Now you need explicity fetch the token and the project's id:

```elixir
defmodule MyApp do
  def kane do
    {:ok, token} = Goth.fetch(MyApp.Goth)
    project_id = Application.fetch_env!(:my_app, :gcp_credentials)["project_id"]

    %Kane{
      project_id: project_id,
      token: token
    }
  end
end

# then
{:ok, messages} = Kane.Subscription.pull(MyApp.kane(), subscription)
```

For more information on earlier versions of Kane, [see v0.9.0 documentation on hexdocs.pm](https://hexdocs.pm/kane/0.9.0).