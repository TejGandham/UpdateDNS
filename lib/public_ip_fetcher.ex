defmodule PublicIPFetcher do
  @moduledoc """
  Fetches the current public IP address using external services.
  Uses multiple fallback services for reliability.
  """

  require Logger

  @ip_services [
    {"https://api.ipify.org?format=json", "ip"},
    {"https://ifconfig.co/json", "ip"},
    {"https://api.my-ip.io/v2/ip.json", "ip"}
  ]

  @doc """
  Fetches the current public IPv4 address.
  Tries multiple services with fallback on failure.
  """
  @spec get_public_ip() :: {:ok, String.t()} | {:error, String.t()}
  def get_public_ip do
    fetch_ip_with_fallback(@ip_services)
  end

  defp fetch_ip_with_fallback([]) do
    {:error, "All IP services failed"}
  end

  defp fetch_ip_with_fallback([{url, key} | rest]) do
    case fetch_from_service(url, key) do
      {:ok, ip} ->
        {:ok, ip}

      {:error, reason} ->
        Logger.warning("IP service #{url} failed: #{reason}")
        fetch_ip_with_fallback(rest)
    end
  end

  defp fetch_from_service(url, key) do
    case Req.get(url, receive_timeout: 10_000) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case Map.get(body, key) do
          nil -> {:error, "Key '#{key}' not found in response"}
          ip -> {:ok, ip}
        end

      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        case JSON.decode(body) do
          {:ok, %{^key => ip}} -> {:ok, ip}
          {:ok, _} -> {:error, "Key '#{key}' not found in response"}
          {:error, _} -> {:error, "Failed to parse JSON response"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end
end
