defmodule Kane do
  @moduledoc """
  Kane. Citizen Kane. Charles Foster Kane, to be exact, Publisher extraordinaire.

  Rosebud.

  Kane is for publishing and subscribing to topics using Google Cloud Pub/Sub.
  """

  @doc """
  Retrieves the default Oauth scope for retrieving an access token
      iex> Kane.oauth_scope
      "https://www.googleapis.com/auth/pubsub"
  """
  @spec oauth_scope :: String.t()
  def oauth_scope, do: "https://www.googleapis.com/auth/pubsub"

  @enforce_keys [:endpoint, :token, :project_id]
  defstruct [:endpoint, :token, :project_id]

  @type t :: %__MODULE__{
    endpoint: String.t(),
    token: Goth.Token.t(),
    project_id: String.t()
  }
end
