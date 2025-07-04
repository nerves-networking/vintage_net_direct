defmodule VintageNetDirect.MixProject do
  use Mix.Project

  @version "0.10.7"
  @source_url "https://github.com/nerves-networking/vintage_net_direct"

  def project do
    [
      app: :vintage_net_direct,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
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

  def cli do
    [preferred_envs: %{docs: :docs, "hex.publish": :docs, "hex.build": :docs, credo: :test}]
  end

  defp description do
    "Direct Ethernet networking for VintageNet"
  end

  defp package do
    %{
      files: [
        "CHANGELOG.md",
        "lib",
        "LICENSES/*",
        "mix.exs",
        "NOTICE",
        "README.md",
        "REUSE.toml"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "REUSE Compliance" =>
          "https://api.reuse.software/info/github.com/nerves-networking/vintage_net_direct"
      }
    }
  end

  defp deps do
    [
      {:vintage_net, "~> 0.9.1 or ~> 0.10.0 or ~> 0.11.0 or ~> 0.12.0 or ~> 0.13.0"},
      {:one_dhcpd, "~> 2.0 or ~> 1.0 or ~> 0.2.3"},
      {:credo, "~> 1.2", only: :test, runtime: false},
      {:dialyxir, "~> 1.4.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false}
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      plt_file: {:no_warn, "_build/plts/dialyzer.plt"}
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
