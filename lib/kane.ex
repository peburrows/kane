defmodule Kane do
  @moduledoc """
  Kane is for publishing and subscribing to topics using Google Cloud Pub/Sub
  """

  @doc """
  Retrieves the default Oauth scope for retrieving an access token
  """
  def oauth_scope, do: "https://www.googleapis.com/auth/pubsub"
end
