defmodule UpdateDNS.HTTPClient.ReqImpl do
  @moduledoc "Production HTTP client implementation using Req"
  @behaviour UpdateDNS.HTTPClient

  @impl true
  def get(url_or_client, opts \\ [])

  def get(url, opts) when is_binary(url) do
    Req.get(url, opts)
  end

  def get(%Req.Request{} = client, opts) do
    Req.get(client, opts)
  end

  @impl true
  def patch(client, opts) do
    Req.patch(client, opts)
  end
end
