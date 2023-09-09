import Config

import_config "secrets.exs"

config :logger,
  backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "log/production.log",
  level: :info
