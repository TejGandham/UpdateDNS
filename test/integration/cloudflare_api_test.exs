defmodule UpdateDNS.Integration.CloudflareAPITest do
  use UpdateDNS.IntegrationCase, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  describe "DNSRecordManager against real Cloudflare API" do
    test "get_dns_record_id/3 returns valid record ID", ctx do
      result =
        DNSRecordManager.get_dns_record_id(
          ctx.zone_id,
          ctx.api_token,
          ctx.test_record
        )

      assert {:ok, record_id} = result
      assert is_binary(record_id)
      assert String.length(record_id) == 32
    end

    test "get_dns_record_ip/3 returns current IP", ctx do
      result =
        DNSRecordManager.get_dns_record_ip(
          ctx.zone_id,
          ctx.api_token,
          ctx.test_record
        )

      assert {:ok, ip} = result
      assert ip =~ ~r/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
    end

    test "update_dns_record/6 successfully updates record", ctx do
      {:ok, record_id} =
        DNSRecordManager.get_dns_record_id(
          ctx.zone_id,
          ctx.api_token,
          ctx.test_record
        )

      {:ok, original_ip} =
        DNSRecordManager.get_dns_record_ip(
          ctx.zone_id,
          ctx.api_token,
          ctx.test_record
        )

      test_ip = random_test_ip()

      try do
        result =
          DNSRecordManager.force_update_dns_record(
            ctx.zone_id,
            ctx.api_token,
            record_id,
            test_ip,
            ctx.test_record,
            "integration_test"
          )

        assert result == :ok

        # Verify the update took effect
        :timer.sleep(1000)

        {:ok, new_ip} =
          DNSRecordManager.get_dns_record_ip(
            ctx.zone_id,
            ctx.api_token,
            ctx.test_record
          )

        assert new_ip == test_ip
      after
        # Restore original IP
        DNSRecordManager.force_update_dns_record(
          ctx.zone_id,
          ctx.api_token,
          record_id,
          original_ip,
          ctx.test_record,
          "integration_test"
        )
      end
    end

    test "returns error for non-existent record", ctx do
      result =
        DNSRecordManager.get_dns_record_id(
          ctx.zone_id,
          ctx.api_token,
          "nonexistent.#{:rand.uniform(100_000)}.example.com"
        )

      assert {:error, message} = result
      assert message =~ "not found"
    end

    test "returns error for invalid API token", ctx do
      result =
        DNSRecordManager.get_dns_record_id(
          ctx.zone_id,
          "invalid_token_xyz",
          ctx.test_record
        )

      assert {:error, _message} = result
    end
  end

  describe "UpdateCloudflareDNS full workflow" do
    test "check_ip/0 returns valid public IP" do
      result = UpdateCloudflareDNS.check_ip()

      assert {:ok, ip} = result
      assert ip =~ ~r/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
    end

    test "run/1 successfully fetches IP and updates DNS", ctx do
      Application.put_env(:update_dns, :zones, [
        %{
          zone_id: ctx.zone_id,
          api_token: ctx.api_token,
          records: [%{name: ctx.test_record}]
        }
      ])

      {:ok, original_ip} =
        DNSRecordManager.get_dns_record_ip(
          ctx.zone_id,
          ctx.api_token,
          ctx.test_record
        )

      try do
        result = UpdateCloudflareDNS.run(force: true)

        assert {:ok, [%{record_name: record_name, ip: ip, result: :ok}]} = result
        assert record_name == ctx.test_record
        assert is_binary(ip)
      after
        {:ok, record_id} =
          DNSRecordManager.get_dns_record_id(
            ctx.zone_id,
            ctx.api_token,
            ctx.test_record
          )

        DNSRecordManager.force_update_dns_record(
          ctx.zone_id,
          ctx.api_token,
          record_id,
          original_ip,
          ctx.test_record,
          "restore"
        )
      end
    end
  end
end
