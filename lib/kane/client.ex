defmodule Kane.Client do
  alias Response.Success
  alias Response.Error

  @token_mod Application.get_env(:kane, :token, Goth.Token)

  @spec get(binary) :: Success.t | Error.t
  def get(path) do
    url(path)
    |> HTTPoison.get([auth_header()])
    |> handle_response
  end

  @spec put(binary, any) :: Success.t | Error.t
  def put(path, data \\ "") do
    url(path)
    |> HTTPoison.put(encode!(data), [auth_header()])
    |> handle_response
  end

  @spec post(binary, any) :: Success.t | Error.t
  def post(path, data) do
    url(path)
    |> HTTPoison.post(encode!(data), [auth_header()])
    |> handle_response
  end

  @spec delete(binary) :: Success.t | Error.t
  def delete(path) do
    url(path)
    |> HTTPoison.delete([auth_header()])
    |> handle_response
  end

  defp url(path), do: Path.join([endpoint(), path])

  defp endpoint, do: Application.get_env(:kane, :endpoint, "https://pubsub.googleapis.com/v1")

  defp auth_header do
    {:ok, token} = @token_mod.for_scope(Kane.oauth_scope())
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

  defp encode!(""), do: ""
  defp encode!(data), do: Poison.encode!(data)
end
