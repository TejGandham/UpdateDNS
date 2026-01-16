defmodule UpdateCloudflareDNS do
  @moduledoc """
  Main module for updating Cloudflare DNS records with current public IP.

  Supports multiple zones and records with optional manual IP overrides.

  ## Configuration

  Zone-centric format (recommended):

      config :update_dns, :zones, [
        %{
          zone_id: "your_zone_id",
          api_token: "your_api_token",
          records: [
            %{name: "home.example.com"},                    # Uses auto-detected IP
            %{name: "vpn.example.com"},                     # Uses auto-detected IP
            %{name: "internal.example.com", ip: "10.0.0.5"} # Uses manual IP
          ]
        }
      ]

  Legacy single-record format (still supported):

      config :update_dns, :cloudflare,
        zone_id: "your_zone_id",
        api_token: "your_api_token",
        record_name: "home.example.com"

  ## Usage

      # Run update (respects IP cache)
      UpdateCloudflareDNS.run()

      # Force update (ignores cache)
      UpdateCloudflareDNS.run(force: true)
  """

  require Logger

  @doc """
  Runs the DNS update process for all configured zones and records.

  ## Options
    * `:force` - If true, updates DNS even if IP hasn't changed (default: false)

  ## Returns
    * `{:ok, results}` - List of results per record
    * `{:error, reason}` - If a critical error occurs (e.g., can't fetch public IP)
  """
  @spec run(keyword()) :: {:ok, list()} | {:error, String.t()}
  def run(opts \\ []) do
    force = Keyword.get(opts, :force, false)
    zones = load_zones_config()

    Logger.info("Starting Cloudflare DNS update for #{count_records(zones)} record(s)...")

    # Pre-fetch public IP for records that need it
    auto_ip_result = fetch_auto_ip_if_needed(zones)

    case auto_ip_result do
      {:ok, auto_ip} ->
        results = update_all_zones(zones, auto_ip, force)
        log_summary(results)
        {:ok, results}

      {:error, reason} ->
        Logger.error("Failed to fetch public IP: #{reason}")
        {:error, reason}
    end
  end

  defp load_zones_config do
    case Application.get_env(:update_dns, :zones) do
      nil -> load_legacy_config()
      zones when is_list(zones) -> zones
    end
  end

  defp load_legacy_config do
    case Application.get_env(:update_dns, :cloudflare) do
      nil ->
        []

      config ->
        [
          %{
            zone_id: config[:zone_id],
            api_token: config[:api_token],
            records: [%{name: config[:record_name]}]
          }
        ]
    end
  end

  defp count_records(zones) do
    Enum.reduce(zones, 0, fn zone, acc ->
      acc + length(Map.get(zone, :records, []))
    end)
  end

  defp fetch_auto_ip_if_needed(zones) do
    needs_auto_ip? =
      Enum.any?(zones, fn zone ->
        Enum.any?(zone.records, fn record ->
          not Map.has_key?(record, :ip)
        end)
      end)

    if needs_auto_ip? do
      PublicIPFetcher.get_public_ip()
    else
      {:ok, nil}
    end
  end

  defp update_all_zones(zones, auto_ip, force) do
    Enum.flat_map(zones, fn zone ->
      update_zone_records(zone, auto_ip, force)
    end)
  end

  defp update_zone_records(zone, auto_ip, force) do
    %{zone_id: zone_id, api_token: api_token, records: records} = zone

    Enum.map(records, fn record ->
      update_single_record(zone_id, api_token, record, auto_ip, force)
    end)
  end

  defp update_single_record(zone_id, api_token, record, auto_ip, force) do
    record_name = record.name
    {ip, ip_key} = resolve_ip(record, auto_ip)

    Logger.info("Processing #{record_name} with IP #{ip}...")

    result =
      with {:ok, record_id} <- DNSRecordManager.get_dns_record_id(zone_id, api_token, record_name) do
        if force do
          DNSRecordManager.force_update_dns_record(
            zone_id,
            api_token,
            record_id,
            ip,
            record_name,
            ip_key
          )
        else
          DNSRecordManager.update_dns_record(
            zone_id,
            api_token,
            record_id,
            ip,
            record_name,
            ip_key
          )
        end
      end

    %{record_name: record_name, ip: ip, result: result}
  end

  defp resolve_ip(record, auto_ip) do
    case Map.get(record, :ip) do
      nil -> {auto_ip, "auto"}
      manual_ip -> {manual_ip, manual_ip}
    end
  end

  defp log_summary(results) do
    {ok, unchanged, errors} =
      Enum.reduce(results, {0, 0, 0}, fn %{result: result}, {ok, unchanged, errors} ->
        case result do
          :ok -> {ok + 1, unchanged, errors}
          :unchanged -> {ok, unchanged + 1, errors}
          {:error, _} -> {ok, unchanged, errors + 1}
        end
      end)

    Logger.info("Summary: #{ok} updated, #{unchanged} unchanged, #{errors} failed")

    Enum.each(results, fn %{record_name: name, ip: ip, result: result} ->
      case result do
        :ok -> Logger.info("  ✓ #{name} -> #{ip}")
        :unchanged -> Logger.info("  - #{name} (unchanged)")
        {:error, reason} -> Logger.error("  ✗ #{name}: #{reason}")
      end
    end)
  end

  @doc """
  Clears all IP caches, causing the next run to update DNS regardless of IP.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    DNSRecordManager.clear_all_caches()
  end

  @doc """
  Returns the current public IP without updating DNS.
  """
  @spec check_ip() :: {:ok, String.t()} | {:error, String.t()}
  def check_ip do
    PublicIPFetcher.get_public_ip()
  end

  @doc """
  Returns the IP currently set in DNS for all configured records.
  """
  @spec check_dns_ip() :: list(map())
  def check_dns_ip do
    zones = load_zones_config()

    Enum.flat_map(zones, fn zone ->
      %{zone_id: zone_id, api_token: api_token, records: records} = zone

      Enum.map(records, fn record ->
        result = DNSRecordManager.get_dns_record_ip(zone_id, api_token, record.name)
        %{record_name: record.name, result: result}
      end)
    end)
  end
end
