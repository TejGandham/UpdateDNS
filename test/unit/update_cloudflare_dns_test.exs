defmodule UpdateCloudflareDNSTest do
  use ExUnit.Case, async: true
  import Mox
  import UpdateDNS.TestFixtures

  setup :verify_on_exit!

  setup do
    temp_dir = Path.join(System.tmp_dir!(), "update_dns_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(temp_dir)
    Application.put_env(:update_dns, :ip_cache_dir, temp_dir)

    on_exit(fn ->
      Application.delete_env(:update_dns, :zones)
      File.rm_rf!(temp_dir)
    end)

    %{temp_dir: temp_dir}
  end

  describe "run/1" do
    test "successfully updates single record with auto IP" do
      Application.put_env(:update_dns, :zones, zones_config())

      UpdateDNS.MockHTTPClient
      # IP fetch
      |> expect(:get, fn url, _opts when is_binary(url) ->
        {:ok, %{status: 200, body: ip_service_response()}}
      end)
      # Get record ID
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_dns_record_response()}}
      end)
      # Update
      |> expect(:patch, fn _client, opts ->
        assert opts[:json] == %{content: valid_ip()}
        {:ok, %{status: 200, body: cloudflare_update_success_response()}}
      end)

      assert {:ok, [%{record_name: "home.example.com", ip: "203.0.113.42", result: :ok}]} =
               UpdateCloudflareDNS.run()
    end

    test "handles multiple records in same zone" do
      config = [
        %{
          zone_id: zone_id(),
          api_token: api_token(),
          records: [%{name: "a.example.com"}, %{name: "b.example.com"}]
        }
      ]

      Application.put_env(:update_dns, :zones, config)

      UpdateDNS.MockHTTPClient
      # IP fetch (once)
      |> expect(:get, fn url, _opts when is_binary(url) ->
        {:ok, %{status: 200, body: ip_service_response()}}
      end)
      # Record ID lookups (2 records)
      |> expect(:get, 2, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_dns_record_response()}}
      end)
      # Updates (2 records)
      |> expect(:patch, 2, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_update_success_response()}}
      end)

      {:ok, results} = UpdateCloudflareDNS.run()
      assert length(results) == 2
      assert Enum.all?(results, &(&1.result == :ok))
    end

    test "uses manual IP when specified" do
      manual_ip = "192.168.1.100"

      config = [
        %{
          zone_id: zone_id(),
          api_token: api_token(),
          records: [%{name: record_name(), ip: manual_ip}]
        }
      ]

      Application.put_env(:update_dns, :zones, config)

      # No IP service call expected since all records have manual IP
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_dns_record_response()}}
      end)
      |> expect(:patch, fn _client, opts ->
        assert opts[:json] == %{content: manual_ip}
        {:ok, %{status: 200, body: cloudflare_update_success_response()}}
      end)

      {:ok, [%{ip: ^manual_ip}]} = UpdateCloudflareDNS.run()
    end

    test "force option bypasses cache", %{temp_dir: temp_dir} do
      Application.put_env(:update_dns, :zones, zones_config())

      # Pre-cache the IP
      File.write!(Path.join(temp_dir, "update_dns_ip_auto.txt"), valid_ip())

      UpdateDNS.MockHTTPClient
      |> expect(:get, fn url, _opts when is_binary(url) ->
        {:ok, %{status: 200, body: ip_service_response()}}
      end)
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_dns_record_response()}}
      end)
      |> expect(:patch, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_update_success_response()}}
      end)

      {:ok, [%{result: :ok}]} = UpdateCloudflareDNS.run(force: true)
    end

    test "returns error when IP fetch fails and records need auto IP" do
      Application.put_env(:update_dns, :zones, zones_config())

      UpdateDNS.MockHTTPClient
      |> expect(:get, 3, fn _, _ -> {:ok, %{status: 500, body: ""}} end)

      assert {:error, "All IP services failed"} = UpdateCloudflareDNS.run()
    end

    test "continues processing when one record fails" do
      config = [
        %{
          zone_id: zone_id(),
          api_token: api_token(),
          records: [
            %{name: "good.example.com"},
            %{name: "bad.example.com"}
          ]
        }
      ]

      Application.put_env(:update_dns, :zones, config)

      UpdateDNS.MockHTTPClient
      |> expect(:get, fn url, _opts when is_binary(url) ->
        {:ok, %{status: 200, body: ip_service_response()}}
      end)
      # First record: success
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_dns_record_response()}}
      end)
      |> expect(:patch, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_update_success_response()}}
      end)
      # Second record: not found
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_empty_response()}}
      end)

      {:ok, results} = UpdateCloudflareDNS.run()

      assert length(results) == 2
      assert Enum.count(results, &(&1.result == :ok)) == 1
      assert Enum.count(results, &match?({:error, _}, &1.result)) == 1
    end

    test "returns empty results when no zones configured" do
      Application.put_env(:update_dns, :zones, [])

      assert {:ok, []} = UpdateCloudflareDNS.run()
    end
  end

  describe "check_ip/0" do
    test "returns current public IP" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _, _ ->
        {:ok, %{status: 200, body: ip_service_response()}}
      end)

      assert {:ok, valid_ip()} = UpdateCloudflareDNS.check_ip()
    end
  end

  describe "check_dns_ip/0" do
    test "returns DNS IP for all configured records" do
      Application.put_env(:update_dns, :zones, zones_config())

      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _client, _opts ->
        {:ok, %{status: 200, body: cloudflare_dns_record_response(content: valid_ip())}}
      end)

      assert [%{record_name: "home.example.com", result: {:ok, "203.0.113.42"}}] =
               UpdateCloudflareDNS.check_dns_ip()
    end
  end

  describe "clear_cache/0" do
    test "clears all IP caches", %{temp_dir: temp_dir} do
      File.write!(Path.join(temp_dir, "update_dns_ip_auto.txt"), "1.2.3.4")

      UpdateCloudflareDNS.clear_cache()

      refute File.exists?(Path.join(temp_dir, "update_dns_ip_auto.txt"))
    end
  end
end
