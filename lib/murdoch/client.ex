defmodule Murdoch.Client do
  @token_mod Application.get_env(:murdoch, :token, Goth.Token)

  def put(path, data \\ "") do
    url(path)
    |> HTTPoison.put(data, [auth_header])
    |> handle_response
  end

  def post(path, data) do
    url(path)
    |> HTTPoison.post(Poison.encode!(data), [auth_header])
    |> handle_response
  end

  defp url(path), do: Path.join([endpoint, path])

  defp endpoint, do: Application.get_env(:murdoch, :endpoint, "https://pubsub.googleapis.com/v1")

  defp auth_header do
    {:ok, token} = @token_mod.for_scope(Murdoch.oauth_scope)
    {"Authorization", "#{token.type} #{token.token}"}
  end

  defp handle_response({:ok, response}), do: handle_status(response)
  defp handle_response(err), do: err

  defp handle_status(response) do
    case response.status_code do
      code when code in 200..299 ->
        {:ok, response.body, code}
      err ->
        {:error, response.body, err}
    end
  end
end
