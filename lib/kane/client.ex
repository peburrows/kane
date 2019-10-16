defmodule Kane.TestToken do
  def for_scope(scope) do
    {:ok,
     %Goth.Token{
       scope: scope,
       expires: :os.system_time(:seconds) + 3600,
       type: "Bearer",
       token: UUID.uuid1()
     }}
  end
end

defmodule Kane.Client do
  alias Response.Success
  alias Response.Error
  require Logger

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

  defp token_mod() do
    local = Application.get_env(:kane, :local, false)

    if local do
      Kane.TestToken.for_scope(:development)
    else
      {:ok, Application.get_env(:kane, :token, Goth.Token).for_scope(Kane.oauth_scope())}
    end
  end

  defp auth_header do
    {:ok, token} = token_mod()
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
