defmodule UpdateDNS.IntegrationCase do
  @moduledoc """
  Case template for integration tests that hit real Cloudflare API.

  Requires environment variables:
  - CLOUDFLARE_ZONE_ID
  - CLOUDFLARE_API_TOKEN
  - CLOUDFLARE_TEST_RECORD (e.g., "test.example.com")
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import UpdateDNS.IntegrationCase
    end
  end

  setup do
    zone_id = System.get_env("CLOUDFLARE_ZONE_ID")
    api_token = System.get_env("CLOUDFLARE_API_TOKEN")
    test_record = System.get_env("CLOUDFLARE_TEST_RECORD")

    unless zone_id && api_token && test_record do
      raise """
      Integration tests require environment variables:
        CLOUDFLARE_ZONE_ID
        CLOUDFLARE_API_TOKEN
        CLOUDFLARE_TEST_RECORD
      """
    end

    # Use real HTTP client for integration tests
    Application.put_env(:update_dns, :http_client, UpdateDNS.HTTPClient.ReqImpl)

    # Set up temp cache directory
    temp_dir = Path.join(System.tmp_dir!(), "update_dns_integration_#{:rand.uniform(100_000)}")
    File.mkdir_p!(temp_dir)
    Application.put_env(:update_dns, :ip_cache_dir, temp_dir)

    on_exit(fn ->
      File.rm_rf!(temp_dir)
    end)

    %{
      zone_id: zone_id,
      api_token: api_token,
      test_record: test_record,
      temp_dir: temp_dir
    }
  end

  def random_test_ip do
    # Using TEST-NET-1 range (192.0.2.0/24) reserved for documentation
    "192.0.2.#{:rand.uniform(254)}"
  end
end
