defmodule Dbus.Mixfile do
  use Mix.Project

  def project do
    [app: :dbus,
     version: "0.1.0",
     elixir: "~> 1.0",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :eredis],
     mod: {Dbus, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:eredis,  "~> 1.0"},
     {:poolboy,  "~> 1.4"}]
  end
end
