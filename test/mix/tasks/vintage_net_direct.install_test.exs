# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.VintageNetDirect.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  @nerves_new_config """
  import Config

  # Configure the network using vintage_net
  #
  # Update regulatory_domain to your 2-letter country code E.g., "US"
  #
  # See https://github.com/nerves-networking/vintage_net for more information
  config :vintage_net,
    regulatory_domain: "00",
    config: [
      {"usb0", %{type: VintageNetDirect}},
      {"eth0",
       %{
         type: VintageNetEthernet,
         ipv4: %{method: :dhcp}
       }},
      {"wlan0", %{type: VintageNetWiFi}}
    ]
  """

  defp nerves_project(target_exs \\ "import Config\n") do
    test_project(files: %{"config/target.exs" => target_exs})
  end

  defp install(igniter, argv \\ []) do
    Igniter.compose_task(igniter, "vintage_net_direct.install", argv)
  end

  test "adds usb0 to config/target.exs in Nerves projects" do
    igniter =
      nerves_project()
      |> install()
      |> assert_has_patch("config/target.exs", """
      + |config :vintage_net, config: [{"usb0", %{type: VintageNetDirect}}]
      """)
      |> assert_unchanged("config/config.exs")
      |> assert_has_notice(
        &(&1 =~ ~s("usb0" was added to the network interfaces in config/target.exs))
      )
      |> assert_has_notice(&(&1 =~ "USB gadget mode"))
      |> assert_has_notice(&(&1 =~ "Add `mdns_lite` or `nerves_pack`"))

    assert length(igniter.notices) == 1
    assert igniter.warnings == []
    assert igniter.issues == []
  end

  test "falls back to config/config.exs with a notice" do
    igniter =
      test_project()
      |> install()
      |> assert_creates("config/config.exs", """
      import Config
      config :vintage_net, config: [{"usb0", %{type: VintageNetDirect}}]
      """)
      |> refute_creates("config/target.exs")
      |> assert_has_notice(&(&1 =~ "config/target.exs was not found"))
      |> assert_has_notice(
        &(&1 =~ ~s("usb0" was added to the network interfaces in config/config.exs))
      )

    assert length(igniter.notices) == 2
  end

  test "is idempotent" do
    igniter =
      nerves_project()
      |> install()
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()

    assert igniter.notices == []

    test_project()
    |> install(["--direct-ifname", "usb1"])
    |> apply_igniter!()
    |> install(["--direct-ifname", "usb1"])
    |> assert_unchanged()
  end

  test "leaves the Nerves new project config alone" do
    igniter = nerves_project(@nerves_new_config) |> install() |> assert_unchanged()

    assert igniter.notices == []
    assert igniter.warnings == []
  end

  test "keeps a customized usb0" do
    igniter =
      nerves_project("""
      import Config

      config :vintage_net,
        regulatory_domain: "US",
        config: [
          {"usb0", %{type: VintageNetDirect, vintage_net_direct: %{hostname: "my-device"}}},
          {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
        ]
      """)
      |> install()
      |> assert_unchanged()

    assert igniter.notices == []
  end

  test "keeps usb0 when it's used for something else" do
    config = """
    import Config

    config :vintage_net,
      regulatory_domain: "00",
      config: [
        {"usb0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
        {"wlan0", %{type: VintageNetWiFi, ipv4: %{method: :dhcp}}}
      ]
    """

    igniter = nerves_project(config) |> install() |> assert_unchanged()

    assert igniter.notices == []
  end

  test "appends to the other network interfaces" do
    nerves_project("""
    import Config

    config :vintage_net,
      regulatory_domain: "SE",
      config: [
        {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
        {"wlan0", %{type: VintageNetWiFi}}
      ]
    """)
    |> install()
    |> apply_igniter!()
    |> assert_content_equals("config/target.exs", """
    import Config

    config :vintage_net,
      regulatory_domain: "SE",
      config: [
        {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
        {"wlan0", %{type: VintageNetWiFi}},
        {"usb0", %{type: VintageNetDirect}}
      ]
    """)
  end

  test "adds to the base config from vintage_net.install" do
    nerves_project("""
    import Config

    config :vintage_net, regulatory_domain: "US", config: []
    """)
    |> install()
    |> assert_has_patch("config/target.exs", """
    - |config :vintage_net, regulatory_domain: "US", config: []
    + |config :vintage_net, regulatory_domain: "US", config: [{"usb0", %{type: VintageNetDirect}}]
    """)
  end

  test "warns when the network interfaces aren't a list" do
    igniter =
      nerves_project("""
      import Config

      interfaces = [{"eth0", %{type: VintageNetEthernet}}]

      config :vintage_net, regulatory_domain: "US", config: interfaces
      """)
      |> install()
      |> assert_unchanged()
      |> assert_has_warning(&(&1 =~ ~s({"usb0", %{type: VintageNetDirect}})))

    assert igniter.notices == []
  end

  test "--direct-ifname sets the interface name" do
    nerves_project()
    |> install(["--direct-ifname", "usb1"])
    |> assert_has_patch("config/target.exs", """
    + |config :vintage_net, config: [{"usb1", %{type: VintageNetDirect}}]
    """)
    |> assert_has_notice(&(&1 =~ ~s("usb1" was added)))
  end

  test "--direct-ifname adds a second interface next to usb0" do
    igniter =
      nerves_project(@nerves_new_config)
      |> install(["--direct-ifname", "eth1"])
      |> assert_has_patch("config/target.exs", """
      - |    {"wlan0", %{type: VintageNetWiFi}}
      + |    {"wlan0", %{type: VintageNetWiFi}},
      + |    {"eth1", %{type: VintageNetDirect}}
      """)

    assert length(igniter.notices) == 1
  end

  test "invalid --direct-ifname is an issue" do
    for bad <- ["", "has space", "a/b", "sixteen_chars_xx", ".."] do
      nerves_project()
      |> install(["--direct-ifname", bad])
      |> assert_unchanged()
      |> assert_has_issue(&(&1 =~ "invalid --direct-ifname"))
    end
  end

  test "the notice refers to mdns_lite when the project has it" do
    for dep <- ["mdns_lite", "nerves_pack"] do
      test_project(
        files: %{
          "config/target.exs" => "import Config\n",
          "mix.exs" => """
          defmodule Test.MixProject do
            use Mix.Project

            def project do
              [app: :test, version: "0.1.0", deps: deps()]
            end

            defp deps do
              [{:#{dep}, "~> 0.1"}]
            end
          end
          """
        }
      )
      |> install()
      |> assert_has_notice(&(&1 =~ "hostnames that mdns_lite advertises"))
    end
  end

  test "composes with vintage_net.install in either order" do
    expected = """
    import Config
    config :vintage_net, config: [{"usb0", %{type: VintageNetDirect}}]
    """

    nerves_project()
    |> Igniter.compose_task("vintage_net.install", [])
    |> install()
    |> apply_igniter!()
    |> assert_content_equals("config/target.exs", expected)

    nerves_project()
    |> install()
    |> Igniter.compose_task("vintage_net.install", [])
    |> apply_igniter!()
    |> assert_content_equals("config/target.exs", expected)
  end

  describe "restricting the dependency to the project's targets" do
    defp targets_mix_exs(deps) do
      """
      defmodule Test.MixProject do
        use Mix.Project

        @app :test
        @device_targets [:rpi4, :rpi5]
        @other_targets [:bbb]

        def project do
          [app: @app, version: "0.1.0", deps: deps()]
        end

        defp deps do
          [
            {:nerves, "~> 2.0", runtime: false},
            #{Enum.join(deps, ",\n      ")}
          ]
        end
      end
      """
    end

    defp targets_install(deps) do
      test_project(
        files: %{"mix.exs" => targets_mix_exs(deps), "config/target.exs" => "import Config\n"}
      )
      |> Igniter.compose_task("vintage_net_direct.install", [])
    end

    defp targets_mix_exs_after(igniter) do
      igniter.rewrite |> Rewrite.source!("mix.exs") |> Rewrite.Source.get(:content)
    end

    test "uses the first targets attribute that another dependency uses" do
      igniter =
        targets_install([
          ~s|{:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}|,
          ~s|{:nerves_pack, "~> 0.7", targets: @device_targets}|,
          ~s|{:other, "~> 1.0", targets: @other_targets}|,
          ~s|{:vintage_net_direct, "~> 1.0"}|
        ])

      assert targets_mix_exs_after(igniter) =~
               ~s|{:vintage_net_direct, "~> 1.0", targets: @device_targets}|

      # Running it again changes nothing
      igniter
      |> apply_igniter!()
      |> Igniter.compose_task("vintage_net_direct.install", [])
      |> assert_unchanged("mix.exs")
    end

    test "works for dependencies that only have options" do
      igniter =
        targets_install([
          ~s|{:nerves_pack, "~> 0.7", targets: @device_targets}|,
          ~s|{:vintage_net_direct, path: "../vintage_net_direct"}|
        ])

      assert targets_mix_exs_after(igniter) =~
               ~s|{:vintage_net_direct, path: "../vintage_net_direct", targets: @device_targets}|
    end

    test "keeps the targets that the dependency already has" do
      targets_install([
        ~s|{:nerves_pack, "~> 0.7", targets: @device_targets}|,
        ~s|{:vintage_net_direct, "~> 1.0", targets: [:rpi0]}|
      ])
      |> assert_unchanged("mix.exs")
    end

    test "does nothing when no dependency uses a targets attribute" do
      targets_install([
        ~s|{:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}|,
        ~s|{:vintage_net_direct, "~> 1.0"}|
      ])
      |> assert_unchanged("mix.exs")
    end

    test "falls back to @all_targets when it's defined but not used by a dependency" do
      mix_exs = """
      defmodule Test.MixProject do
        use Mix.Project

        @all_targets [:rpi4, :rpi5]

        def project do
          [app: :test, version: "0.1.0", deps: deps()]
        end

        defp deps do
          [
            {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4},
            {:vintage_net_direct, "~> 1.0"}
          ]
        end
      end
      """

      igniter =
        test_project(files: %{"mix.exs" => mix_exs, "config/target.exs" => "import Config\n"})
        |> Igniter.compose_task("vintage_net_direct.install", [])

      assert targets_mix_exs_after(igniter) =~
               ~s|{:vintage_net_direct, "~> 1.0", targets: @all_targets}|
    end

    test "does nothing when the dependency isn't in mix.exs" do
      targets_install([~s|{:nerves_pack, "~> 0.7", targets: @device_targets}|])
      |> assert_unchanged("mix.exs")
    end
  end
end
