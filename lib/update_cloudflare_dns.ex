defmodule UpdateCloudflareDNS do
  require Logger
  alias PublicIPFetcher
  alias DNSRecordManager
  alias LoggerConfig


  # Load environment variables from .env file
  
  defp subdomain do
    Application.fetch_env!(:update_dns, :cloudflare)[:SUBDOMAIN]
  end

  def run do
    LoggerConfig.configure()
    Logger.info("Starting to update Cloudflare DNS record...")

    with {:ok, public_ip} <- PublicIPFetcher.get_public_ip(),
         # ,
         {:ok, record_id} <- DNSRecordManager.get_dns_record_id(subdomain()), 
       :ok <- DNSRecordManager.update_dns_record(record_id, public_ip, subdomain()) do
      Logger.info("Public ip: #{public_ip}")
      Logger.info("Record ID : #{record_id}")
      Logger.info("Successfully updated Cloudflare DNS record.")
    else
      {:error, reason} -> Logger.error("Failed to update Cloudflare DNS record: #{reason}")
    end
  end
end
