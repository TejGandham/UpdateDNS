import Config

# Use mock HTTP client in tests
config :update_dns,
  http_client: UpdateDNS.MockHTTPClient,
  ip_cache_dir: System.tmp_dir!()

# Reduce log noise in tests
config :logger, level: :warning
