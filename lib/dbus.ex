defmodule Dbus do
  use Application

  alias Dbus.Redis, as: R

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      worker(Dbus.Redis, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dbus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def kill(), do: R.q(["DEL", "topics"])
  def topics(), do: R.q!(["SMEMBERS","topics"])
  def add_topic(name), do: R.q!(["SADD","topics",name])


end
