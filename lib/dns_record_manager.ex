defmodule DNSRecordManager do
  @moduledoc """
  Manages Cloudflare DNS records via API.
  Uses PATCH for partial updates (idiomatic for just changing IP).
  Includes IP caching to avoid unnecessary API calls.

  All functions accept zone credentials as parameters to support
  multi-zone configurations.
  """

  require Logger

  @cloudflare_api_url "https://api.cloudflare.com/client/v4"

  defp http_client do
    Application.get_env(:update_dns, :http_client, UpdateDNS.HTTPClient.ReqImpl)
  end

  defp ip_cache_dir do
    Application.get_env(:update_dns, :ip_cache_dir, "/tmp")
  end

  defp ip_cache_file(ip_key) do
    # Sanitize IP key for filename (replace dots and colons)
    safe_key = ip_key |> String.replace(~r/[.:]/, "_")
    Path.join(ip_cache_dir(), "update_dns_ip_#{safe_key}.txt")
  end

  defp client(api_token) do
    Req.new(
      base_url: @cloudflare_api_url,
      auth: {:bearer, api_token},
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
  @spec get_dns_record_id(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def get_dns_record_id(zone_id, api_token, record_name) do
    url = "/zones/#{zone_id}/dns_records"

    Logger.debug("Fetching DNS record ID for: #{record_name}")

    case http_client().get(client(api_token), url: url, params: [name: record_name, type: "A"]) do
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
  @spec get_dns_record_ip(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def get_dns_record_ip(zone_id, api_token, record_name) do
    url = "/zones/#{zone_id}/dns_records"

    case http_client().get(client(api_token), url: url, params: [name: record_name, type: "A"]) do
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
  Only updates if the IP has changed (per-IP caching).

  The `ip_key` is used for caching - typically "auto" for auto-detected IPs
  or the manual IP itself for manual IPs.
  """
  @spec update_dns_record(String.t(), String.t(), String.t(), String.t(), String.t(), String.t()) ::
          :ok | :unchanged | {:error, String.t()}
  def update_dns_record(zone_id, api_token, record_id, ip, record_name, ip_key) do
    if ip_changed?(ip, ip_key) do
      do_update_dns_record(zone_id, api_token, record_id, ip, record_name, ip_key)
    else
      Logger.info("IP unchanged (#{ip}), skipping update for #{record_name}")
      :unchanged
    end
  end

  @doc """
  Forces a DNS record update regardless of cache.
  """
  @spec force_update_dns_record(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t()
        ) ::
          :ok | {:error, String.t()}
  def force_update_dns_record(zone_id, api_token, record_id, ip, record_name, ip_key) do
    do_update_dns_record(zone_id, api_token, record_id, ip, record_name, ip_key)
  end

  defp do_update_dns_record(zone_id, api_token, record_id, ip, record_name, ip_key) do
    url = "/zones/#{zone_id}/dns_records/#{record_id}"

    Logger.debug("Updating DNS record #{record_name} to IP: #{ip}")

    # Use PATCH for partial update (Cloudflare best practice)
    case http_client().patch(client(api_token), url: url, json: %{content: ip}) do
      {:ok, %{status: status}} when status in 200..299 ->
        cache_ip(ip, ip_key)
        Logger.info("DNS record updated successfully: #{record_name} -> #{ip}")
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to update DNS record: HTTP #{status} - #{inspect(body)}"}

      {:error, exception} ->
        {:error, "Failed to update DNS record: #{Exception.message(exception)}"}
    end
  end

  # IP caching functions (per-IP key)

  defp ip_changed?(new_ip, ip_key) do
    case get_cached_ip(ip_key) do
      {:ok, cached_ip} -> cached_ip != new_ip
      {:error, _} -> true
    end
  end

  defp get_cached_ip(ip_key) do
    case File.read(ip_cache_file(ip_key)) do
      {:ok, content} -> {:ok, String.trim(content)}
      {:error, _} -> {:error, :no_cache}
    end
  end

  defp cache_ip(ip, ip_key) do
    File.write(ip_cache_file(ip_key), ip)
  end

  @doc """
  Clears the IP cache for a specific IP key.
  """
  @spec clear_cache(String.t()) :: :ok | {:error, File.posix()}
  def clear_cache(ip_key) do
    File.rm(ip_cache_file(ip_key))
  end

  @doc """
  Clears all IP caches.
  """
  @spec clear_all_caches() :: :ok
  def clear_all_caches do
    case File.ls(ip_cache_dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.starts_with?(&1, "update_dns_ip_"))
        |> Enum.each(fn file ->
          File.rm(Path.join(ip_cache_dir(), file))
        end)

      {:error, _} ->
        :ok
    end

    :ok
  end
end
