use Mix.Config

config :redis, Dbus.Redis,
  host: System.get_env("REDIS_HOST"),
  port: System.get_env("REDIS_PORT"),
  pool_size: System.get_env("REDIS_POOL_SIZE"),
  max_overflow: System.get_env("REDIS_MAX_OVERFLOW")

config :logger, :console,
  format: "\n$date $time [$level] $metadata$message"

import_config "#{Mix.env}.exs"