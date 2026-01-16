defmodule DNSRecordManager do
  @moduledoc """
  Manages Cloudflare DNS records via API.
  Uses PATCH for partial updates (idiomatic for just changing IP).
  Includes IP caching to avoid unnecessary API calls.
  """

  require Logger

  @cloudflare_api_url "https://api.cloudflare.com/client/v4"

  defp cloudflare_config do
    Application.fetch_env!(:update_dns, :cloudflare)
  end

  defp ip_cache_file do
    Application.get_env(:update_dns, :ip_cache_file, "/tmp/update_dns_last_ip.txt")
  end

  defp client do
    config = cloudflare_config()

    Req.new(
      base_url: @cloudflare_api_url,
      auth: {:bearer, config[:api_token]},
      headers: [{"content-type", "application/json"}],
      receive_timeout: 30_000,
      retry: :transient,
      retry_delay: &retry_delay/1
    )
  end

  defp retry_delay(n), do: 1000 * n

  @doc """
  Gets the DNS record ID for a given record name.
  """
  @spec get_dns_record_id(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def get_dns_record_id(record_name) do
    config = cloudflare_config()
    url = "/zones/#{config[:zone_id]}/dns_records"

    Logger.debug("Fetching DNS record ID for: #{record_name}")

    case Req.get(client(), url: url, params: [name: record_name, type: "A"]) do
      {:ok, %{status: 200, body: %{"result" => [%{"id" => id} | _]}}} ->
        {:ok, id}

      {:ok, %{status: 200, body: %{"result" => []}}} ->
        {:error, "DNS record not found for: #{record_name}"}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to get DNS record: HTTP #{status} - #{inspect(body)}"}

      {:error, exception} ->
        {:error, "Failed to get DNS record: #{Exception.message(exception)}"}
    end
  end

  @doc """
  Gets the current IP from the DNS record.
  """
  @spec get_dns_record_ip(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def get_dns_record_ip(record_name) do
    config = cloudflare_config()
    url = "/zones/#{config[:zone_id]}/dns_records"

    case Req.get(client(), url: url, params: [name: record_name, type: "A"]) do
      {:ok, %{status: 200, body: %{"result" => [%{"content" => ip} | _]}}} ->
        {:ok, ip}

      {:ok, %{status: 200, body: %{"result" => []}}} ->
        {:error, "DNS record not found"}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  @doc """
  Updates the DNS record with a new IP using PATCH (partial update).
  Only updates if the IP has changed.
  """
  @spec update_dns_record(String.t(), String.t(), String.t()) :: :ok | :unchanged | {:error, String.t()}
  def update_dns_record(record_id, ip, record_name) do
    if ip_changed?(ip) do
      do_update_dns_record(record_id, ip, record_name)
    else
      Logger.info("IP unchanged (#{ip}), skipping update")
      :unchanged
    end
  end

  @doc """
  Forces a DNS record update regardless of cache.
  """
  @spec force_update_dns_record(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def force_update_dns_record(record_id, ip, record_name) do
    do_update_dns_record(record_id, ip, record_name)
  end

  defp do_update_dns_record(record_id, ip, record_name) do
    config = cloudflare_config()
    url = "/zones/#{config[:zone_id]}/dns_records/#{record_id}"

    Logger.debug("Updating DNS record #{record_name} to IP: #{ip}")

    # Use PATCH for partial update (Cloudflare best practice)
    case Req.patch(client(), url: url, json: %{content: ip}) do
      {:ok, %{status: status}} when status in 200..299 ->
        cache_ip(ip)
        Logger.info("DNS record updated successfully: #{record_name} -> #{ip}")
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to update DNS record: HTTP #{status} - #{inspect(body)}"}

      {:error, exception} ->
        {:error, "Failed to update DNS record: #{Exception.message(exception)}"}
    end
  end

  # IP caching functions

  defp ip_changed?(new_ip) do
    case get_cached_ip() do
      {:ok, cached_ip} -> cached_ip != new_ip
      {:error, _} -> true
    end
  end

  defp get_cached_ip do
    case File.read(ip_cache_file()) do
      {:ok, content} -> {:ok, String.trim(content)}
      {:error, _} -> {:error, :no_cache}
    end
  end

  defp cache_ip(ip) do
    File.write(ip_cache_file(), ip)
  end

  @doc """
  Clears the IP cache, forcing the next update to proceed.
  """
  @spec clear_cache() :: :ok | {:error, File.posix()}
  def clear_cache do
    File.rm(ip_cache_file())
  end
end
