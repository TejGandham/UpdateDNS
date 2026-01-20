defmodule UpdateDNS.TestFixtures do
  @moduledoc "Test data fixtures for DNS update tests"

  def valid_ip, do: "203.0.113.42"
  def alternate_ip, do: "198.51.100.23"

  def zone_id, do: "zone_abc123"
  def api_token, do: "test_token_xyz"
  def record_name, do: "home.example.com"
  def record_id, do: "record_def456"

  def cloudflare_dns_record_response(opts \\ []) do
    %{
      "success" => true,
      "result" => [
        %{
          "id" => Keyword.get(opts, :id, record_id()),
          "name" => Keyword.get(opts, :name, record_name()),
          "type" => "A",
          "content" => Keyword.get(opts, :content, valid_ip()),
          "proxied" => false,
          "ttl" => 1
        }
      ]
    }
  end

  def cloudflare_empty_response do
    %{"success" => true, "result" => []}
  end

  def cloudflare_error_response(message \\ "Unknown error") do
    %{
      "success" => false,
      "errors" => [%{"code" => 1000, "message" => message}]
    }
  end

  def cloudflare_update_success_response do
    %{
      "success" => true,
      "result" => %{
        "id" => record_id(),
        "name" => record_name(),
        "content" => valid_ip()
      }
    }
  end

  def ip_service_response(ip \\ nil) do
    %{"ip" => ip || valid_ip()}
  end

  def zones_config(opts \\ []) do
    [
      %{
        zone_id: Keyword.get(opts, :zone_id, zone_id()),
        api_token: Keyword.get(opts, :api_token, api_token()),
        records: Keyword.get(opts, :records, [%{name: record_name()}])
      }
    ]
  end
end
