defmodule DNSRecordManager do
  require Logger

  @cloudflare_api_url "https://api.cloudflare.com/client/v4"
  
  defp cloudflare_config do
    Application.fetch_env!(:update_dns, :cloudflare)
  end

  def get_dns_record_id(subdomain) do
    config = cloudflare_config()
    url = "#{@cloudflare_api_url}/zones/#{config[:CLOUDFLARE_ZONE_ID]}/dns_records?name=#{subdomain}"
    Logger.debug("Get DNS record URL: #{url}")

    headers = [
      {"Authorization", "Bearer #{config[:CLOUDFLARE_API_TOKEN]}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, %{"result" => [%{"id" => id} | _]}} ->
            {:ok, id}

          {:error, reason} ->
            {:error, "Failed to parse DNS record ID response: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Failed to get DNS record ID: HTTP status code #{status_code}"}

      {:error, reason} ->
        {:error, "Failed to get DNS record ID: #{inspect(reason)}"}
    end
  end

  def update_dns_record(record_id, ip, subdomain) do
    config = cloudflare_config()
    url = "#{@cloudflare_api_url}/zones/#{config[:CLOUDFLARE_ZONE_ID]}/dns_records/#{record_id}"
    Logger.debug("Update DNS record URL: #{url}")

    headers = [
      {"Authorization", "Bearer #{config[:CLOUDFLARE_API_TOKEN]}"},
      {"Content-Type", "application/json"}
    ]

    body = Poison.encode!(%{"type" => "A", "name" => subdomain, "content" => ip})

    case HTTPoison.put(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in 200..299 ->
        :ok

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Failed to update DNS record: HTTP status code #{status_code}"}

      {:error, reason} ->
        {:error, "Failed to update DNS record: #{inspect(reason)}"}
    end
  end
end
