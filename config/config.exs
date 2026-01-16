import Config

config :logger,
  backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "log/update_dns.log",
  level: :info

# IP cache directory (stores per-IP cache files)
config :update_dns,
  ip_cache_dir: "/tmp"

import_config "secrets.exs"
