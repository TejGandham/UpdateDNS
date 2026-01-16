defmodule DNSRecordManagerTest do
  # async: false because tests modify Application env for ip_cache_dir
  use ExUnit.Case, async: false
  import Mox
  import UpdateDNS.TestFixtures

  setup :verify_on_exit!

  setup do
    temp_dir = Path.join(System.tmp_dir!(), "update_dns_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(temp_dir)
    Application.put_env(:update_dns, :ip_cache_dir, temp_dir)

    on_exit(fn ->
      File.rm_rf!(temp_dir)
    end)

    %{temp_dir: temp_dir}
  end

  describe "get_dns_record_id/3" do
    test "returns record ID when found" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _client, opts ->
        assert opts[:params] == [name: record_name(), type: "A"]
        {:ok, %{status: 200, body: cloudflare_dns_record_response()}}
      end)

      assert {:ok, record_id()} ==
               DNSRecordManager.get_dns_record_id(zone_id(), api_token(), record_name())
    end

    test "returns error when record not found" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_empty_response()}}
      end)

      assert {:error, "DNS record not found for: " <> record_name()} ==
               DNSRecordManager.get_dns_record_id(zone_id(), api_token(), record_name())
    end

    test "returns error on HTTP failure" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 401, body: %{"errors" => [%{"message" => "Unauthorized"}]}}}
      end)

      {:error, message} = DNSRecordManager.get_dns_record_id(zone_id(), api_token(), record_name())
      assert message =~ "HTTP 401"
    end

    test "returns error on network failure" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _client, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      {:error, message} = DNSRecordManager.get_dns_record_id(zone_id(), api_token(), record_name())
      assert message =~ "Failed to get DNS record"
    end
  end

  describe "get_dns_record_ip/3" do
    test "returns current IP from DNS record" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_dns_record_response(content: valid_ip())}}
      end)

      assert {:ok, valid_ip()} ==
               DNSRecordManager.get_dns_record_ip(zone_id(), api_token(), record_name())
    end

    test "returns error when record not found" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_empty_response()}}
      end)

      assert {:error, "DNS record not found"} ==
               DNSRecordManager.get_dns_record_ip(zone_id(), api_token(), record_name())
    end
  end

  describe "update_dns_record/6" do
    test "updates DNS when IP has changed" do
      UpdateDNS.MockHTTPClient
      |> expect(:patch, fn _client, opts ->
        assert opts[:json] == %{content: valid_ip()}
        {:ok, %{status: 200, body: cloudflare_update_success_response()}}
      end)

      assert :ok ==
               DNSRecordManager.update_dns_record(
                 zone_id(),
                 api_token(),
                 record_id(),
                 valid_ip(),
                 record_name(),
                 "test_key"
               )
    end

    test "returns :unchanged when IP matches cache", %{temp_dir: temp_dir} do
      # Pre-cache the IP
      File.write!(Path.join(temp_dir, "update_dns_ip_cached_key.txt"), valid_ip())

      # No mock expected - should return :unchanged without API call
      assert :unchanged ==
               DNSRecordManager.update_dns_record(
                 zone_id(),
                 api_token(),
                 record_id(),
                 valid_ip(),
                 record_name(),
                 "cached_key"
               )
    end

    test "updates when IP differs from cache", %{temp_dir: temp_dir} do
      # Cache old IP
      File.write!(Path.join(temp_dir, "update_dns_ip_diff_key.txt"), "1.2.3.4")

      UpdateDNS.MockHTTPClient
      |> expect(:patch, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_update_success_response()}}
      end)

      assert :ok ==
               DNSRecordManager.update_dns_record(
                 zone_id(),
                 api_token(),
                 record_id(),
                 valid_ip(),
                 record_name(),
                 "diff_key"
               )
    end

    test "returns error on API failure" do
      UpdateDNS.MockHTTPClient
      |> expect(:patch, fn _client, _opts ->
        {:ok, %{status: 400, body: cloudflare_error_response("Invalid IP")}}
      end)

      {:error, message} =
        DNSRecordManager.update_dns_record(
          zone_id(),
          api_token(),
          record_id(),
          "invalid",
          record_name(),
          "error_key"
        )

      assert message =~ "Failed to update DNS record"
    end
  end

  describe "force_update_dns_record/6" do
    test "always updates regardless of cache", %{temp_dir: temp_dir} do
      # Cache the same IP
      File.write!(Path.join(temp_dir, "update_dns_ip_force_key.txt"), valid_ip())

      UpdateDNS.MockHTTPClient
      |> expect(:patch, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_update_success_response()}}
      end)

      # Should still update even though cached IP matches
      assert :ok ==
               DNSRecordManager.force_update_dns_record(
                 zone_id(),
                 api_token(),
                 record_id(),
                 valid_ip(),
                 record_name(),
                 "force_key"
               )
    end
  end

  describe "cache management" do
    test "clear_cache/1 removes specific cache file", %{temp_dir: temp_dir} do
      cache_file = Path.join(temp_dir, "update_dns_ip_clear_test.txt")
      File.write!(cache_file, "1.2.3.4")

      assert File.exists?(cache_file)
      DNSRecordManager.clear_cache("clear_test")
      refute File.exists?(cache_file)
    end

    test "clear_all_caches/0 removes all cache files", %{temp_dir: temp_dir} do
      File.write!(Path.join(temp_dir, "update_dns_ip_a.txt"), "1.1.1.1")
      File.write!(Path.join(temp_dir, "update_dns_ip_b.txt"), "2.2.2.2")
      File.write!(Path.join(temp_dir, "other_file.txt"), "keep me")

      DNSRecordManager.clear_all_caches()

      refute File.exists?(Path.join(temp_dir, "update_dns_ip_a.txt"))
      refute File.exists?(Path.join(temp_dir, "update_dns_ip_b.txt"))
      assert File.exists?(Path.join(temp_dir, "other_file.txt"))
    end
  end
end
