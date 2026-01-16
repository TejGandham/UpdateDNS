defmodule PublicIPFetcherTest do
  use ExUnit.Case, async: true
  import Mox
  import UpdateDNS.TestFixtures

  setup :verify_on_exit!

  describe "get_public_ip/0" do
    test "returns IP from first successful service" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn url, _opts ->
        assert url =~ "ipify"
        {:ok, %{status: 200, body: ip_service_response()}}
      end)

      assert {:ok, valid_ip()} == PublicIPFetcher.get_public_ip()
    end

    test "falls back to second service when first fails" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn url, _opts ->
        assert url =~ "ipify"
        {:ok, %{status: 500, body: "Server Error"}}
      end)
      |> expect(:get, fn url, _opts ->
        assert url =~ "ifconfig"
        {:ok, %{status: 200, body: ip_service_response()}}
      end)

      assert {:ok, valid_ip()} == PublicIPFetcher.get_public_ip()
    end

    test "falls back through all services" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _, _ -> {:ok, %{status: 503, body: ""}} end)
      |> expect(:get, fn _, _ -> {:error, %Req.TransportError{reason: :timeout}} end)
      |> expect(:get, fn _, _ -> {:ok, %{status: 200, body: ip_service_response()}} end)

      assert {:ok, valid_ip()} == PublicIPFetcher.get_public_ip()
    end

    test "returns error when all services fail" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, 3, fn _, _ -> {:ok, %{status: 500, body: ""}} end)

      assert {:error, "All IP services failed"} == PublicIPFetcher.get_public_ip()
    end

    test "handles missing 'ip' key in response" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _, _ ->
        {:ok, %{status: 200, body: %{"address" => "wrong_key"}}}
      end)
      |> expect(:get, fn _, _ ->
        {:ok, %{status: 200, body: ip_service_response()}}
      end)

      assert {:ok, valid_ip()} == PublicIPFetcher.get_public_ip()
    end

    test "handles network timeout" do
      UpdateDNS.MockHTTPClient
      |> expect(:get, fn _, _ ->
        {:error, %Req.TransportError{reason: :timeout}}
      end)
      |> expect(:get, fn _, _ ->
        {:ok, %{status: 200, body: ip_service_response()}}
      end)

      assert {:ok, valid_ip()} == PublicIPFetcher.get_public_ip()
    end
  end
end
