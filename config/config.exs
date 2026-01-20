import Config

config :logger,
  backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "log/update_dns.log",
  level: :info

# IP cache directory (stores per-IP cache files)
config :update_dns,
  ip_cache_dir: "/tmp"

# Import environment-specific config (must be before secrets)
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end

# Import secrets (credentials) - not committed to git
if File.exists?("config/secrets.exs") do
  import_config "secrets.exs"
end
