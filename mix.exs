defmodule VintageNetDirect.MixProject do
  use Mix.Project

  @version "0.7.0"
  @source_url "https://github.com/nerves-networking/vintage_net_direct"

  def project do
    [
      app: :vintage_net_direct,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      description: description()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Direct Ethernet networking for VintageNet"
  end

  defp package do
    %{
      files: [
        "lib",
        "test",
        "mix.exs",
        "README.md",
        "LICENSE",
        "CHANGELOG.md"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :docs, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},
      {:vintage_net,
       github: "nerves-networking/vintage_net", branch: "the-split", override: true},
      {:one_dhcpd, "~> 0.2.3"}
    ]
  end

  defp dialyzer() do
    [
      flags: [:race_conditions, :unmatched_returns, :error_handling, :underspecs]
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
