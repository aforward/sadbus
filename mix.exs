defmodule Dbus.Mixfile do
  use Mix.Project

  @version "0.2.2"
  @source_url "https://github.com/aforward/dbus"

  def project do
    [app: :dbus,
     version: @version,
     elixir: "~> 1.0",
     deps: deps,

     # Hex
     description: description,
     package: package,

     # Docs
     name: "DBus",
     docs: [source_ref: "v#{@version}",
            source_url: @source_url]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :eredis],
     mod: {Dbus, []}]
  end

  defp deps do
    [{:eredis,  "~> 1.0"},
     {:poolboy,  "~> 1.4"}]
  end

  defp description do
    """
    A dumb message bus for sharing data between microservices in a relatively decoupled
    """
  end

  defp package do
    [contributors: ["Andrew Forward"],
     licenses: ["MIT"],
     links: %{"GitHub" => @source_url},
     files: ~w(mix.exs README.md CHANGELOG.md lib)]
  end

end
