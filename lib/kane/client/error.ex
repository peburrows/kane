defmodule Response.Error do
  @moduledoc false
  @type t :: {:error, binary, {:error, HTTPoison.Error.t}}
end
