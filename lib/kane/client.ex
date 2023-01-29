defmodule Kane.Client do
  @moduledoc false

  @type success :: {:ok, body :: String.t(), status_code :: pos_integer()}
  @type error :: {:error, body :: String.t(), status_code :: pos_integer()}

  @spec get(Kane.t(), binary, keyword) :: success() | error()
  def get(kane, path, options \\ []), do: call(kane, :get, path, options)

  @spec put(Kane.t(), binary, any, keyword) :: success() | error()
  def put(kane, path, data \\ "", options \\ []), do: call(kane, :put, path, data, options)

  @spec post(Kane.t(), binary, any, keyword) :: success() | error()
  def post(kane, path, data, options \\ []), do: call(kane, :post, path, data, options)

  @spec delete(Kane.t(), binary, keyword) :: success() | error()
  def delete(kane, path, options \\ []), do: call(kane, :delete, path, options)

  defp call(kane, method, path, options) do
    headers = [auth_header(kane)]
    url = url(kane, path)

    method
    |> HTTPoison.request(url, "", headers, options)
    |> handle_response()
  end

  defp call(kane, method, path, data, options) do
    headers = [auth_header(kane), {"content-type", "application/json"}]
    url = url(kane, path)

    method
    |> HTTPoison.request(url, encode!(data), headers, options)
    |> handle_response()
  end

  defp url(%Kane{endpoint: endpoint}, path), do: Path.join([endpoint, path])

  defp auth_header(%Kane{token: token}) do
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
  defp encode!(data), do: Jason.encode_to_iodata!(data)
end
