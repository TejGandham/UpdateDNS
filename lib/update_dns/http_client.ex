defmodule UpdateDNS.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client operations.
  Allows mocking HTTP calls in tests via Mox.
  """

  @type response :: {:ok, %{status: integer(), body: any()}} | {:error, Exception.t()}

  @callback get(url :: String.t(), opts :: keyword()) :: response()
  @callback get(client :: Req.Request.t(), opts :: keyword()) :: response()
  @callback patch(client :: Req.Request.t(), opts :: keyword()) :: response()
end
