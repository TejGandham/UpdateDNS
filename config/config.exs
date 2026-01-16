import Config

config :logger,
  backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "log/update_dns.log",
  level: :info

# IP cache file location
config :update_dns,
  ip_cache_file: "/tmp/update_dns_last_ip.txt"

import_config "secrets.exs"
