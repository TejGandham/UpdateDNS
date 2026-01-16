defmodule UpdateCloudflareDNS do
  @moduledoc """
  Main module for updating Cloudflare DNS records with current public IP.

  ## Usage

      # Run update (respects IP cache)
      UpdateCloudflareDNS.run()

      # Force update (ignores cache)
      UpdateCloudflareDNS.run(force: true)
  """

  require Logger

  defp record_name do
    Application.fetch_env!(:update_dns, :cloudflare)[:record_name]
  end

  @doc """
  Runs the DNS update process.

  ## Options
    * `:force` - If true, updates DNS even if IP hasn't changed (default: false)
  """
  @spec run(keyword()) :: :ok | :unchanged | {:error, String.t()}
  def run(opts \\ []) do
    force = Keyword.get(opts, :force, false)
    Logger.info("Starting Cloudflare DNS update for #{record_name()}...")

    with {:ok, public_ip} <- PublicIPFetcher.get_public_ip(),
         {:ok, record_id} <- DNSRecordManager.get_dns_record_id(record_name()),
         result <- update_record(record_id, public_ip, force) do
      handle_result(result, public_ip, record_id)
    else
      {:error, reason} ->
        Logger.error("DNS update failed: #{reason}")
        {:error, reason}
    end
  end

  defp update_record(record_id, ip, true = _force) do
    DNSRecordManager.force_update_dns_record(record_id, ip, record_name())
  end

  defp update_record(record_id, ip, false = _force) do
    DNSRecordManager.update_dns_record(record_id, ip, record_name())
  end

  defp handle_result(:ok, ip, record_id) do
    Logger.info("Success! IP: #{ip}, Record ID: #{record_id}")
    :ok
  end

  defp handle_result(:unchanged, ip, _record_id) do
    Logger.info("No update needed. Current IP: #{ip}")
    :unchanged
  end

  defp handle_result({:error, reason}, _ip, _record_id) do
    Logger.error("Update failed: #{reason}")
    {:error, reason}
  end

  @doc """
  Clears the IP cache, causing the next run to update DNS regardless of IP.
  """
  @spec clear_cache() :: :ok | {:error, File.posix()}
  def clear_cache do
    DNSRecordManager.clear_cache()
  end

  @doc """
  Returns the current public IP without updating DNS.
  """
  @spec check_ip() :: {:ok, String.t()} | {:error, String.t()}
  def check_ip do
    PublicIPFetcher.get_public_ip()
  end

  @doc """
  Returns the IP currently set in the DNS record.
  """
  @spec check_dns_ip() :: {:ok, String.t()} | {:error, String.t()}
  def check_dns_ip do
    DNSRecordManager.get_dns_record_ip(record_name())
  end
end
