defmodule Murdoch.Client do
  def put(path, data \\ "") do
    case HTTPoison.put(url(path), data, [auth_header]) do
      {:ok, response} -> handle_response(response)
      err -> err
    end
  end

  def post(path, data) do
    case HTTPoison.post(url(path), Poison.encode!(data), [auth_header]) do
      {:ok, response} -> handle_response(response)
      err -> err
    end
  end

  defp url(path), do: Path.join([endpoint, path])

  defp endpoint, do: Application.get_env(:murdoch, :endpoint, "https://pubsub.googleapis.com/v1")

  defp auth_header do
    {:ok, token} = Goth.Token.for_scope(Murdoch.oauth_scope)
    {"Authorization", "#{token.type} #{token.token}"}
  end

  defp handle_response(response) do
    case response.status_code do
      code when code in 200..299 ->
        {:ok, response.body, code}
      err ->
        {:error, response.body, err}
    end
  end
end
