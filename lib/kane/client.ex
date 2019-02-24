defmodule Kane.Client do
  alias Response.Success
  alias Response.Error

  @spec get(binary, keyword) :: Success.t() | Error.t()
  def get(path, options \\ []), do: call(:get, path, options)

  @spec put(binary, any, keyword) :: Success.t() | Error.t()
  def put(path, data \\ "", options \\ []), do: call(:put, path, data, options)

  @spec post(binary, any, keyword) :: Success.t() | Error.t()
  def post(path, data, options \\ []), do: call(:post, path, data, options)

  @spec delete(binary, keyword) :: Success.t() | Error.t()
  def delete(path, options \\ []), do: call(:delete, path, options)

  defp call(method, path, options) do
    headers = [auth_header()]

    apply(HTTPoison, method, [url(path), headers, options])
    |> handle_response
  end

  defp call(method, path, data, options) do
    headers = [auth_header(), {"content-type", "application/json"}]

    apply(HTTPoison, method, [url(path), encode!(data), headers, options])
    |> handle_response
  end

  defp url(path), do: Path.join([endpoint(), path])

  defp endpoint, do: Application.get_env(:kane, :endpoint, "https://pubsub.googleapis.com/v1")
  defp token_mod, do: Application.get_env(:kane, :token, Goth.Token)

  defp auth_header do
    {:ok, token} = token_mod().for_scope(Kane.oauth_scope())
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
  defp encode!(data), do: Jason.encode!(data)
end
