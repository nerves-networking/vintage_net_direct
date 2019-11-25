defmodule VintageNetGadgetTest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig
  alias VintageNetGadget, as: Gadget

  test "normalization simplifies configuration" do
    input = %{type: Gadget, random_field: 42}

    assert Gadget.normalize(input) == %{type: Gadget, gadget: %{}}
  end

  test "normalization preserves hostname override" do
    input = %{type: Gadget, gadget: %{hostname: "my_host"}}

    assert Gadget.normalize(input) == %{
             type: Gadget,
             gadget: %{hostname: "my_host"}
           }
  end

  test "create a gadget configuration" do
    input = %{
      type: Gadget,
      gadget: %{hostname: "test_hostname"}
    }

    output = Gadget.to_raw_config("usb0", input, default_opts())

    expected = %RawConfig{
      ifname: "usb0",
      type: Gadget,
      source_config: input,
      child_specs: [
        %{id: {OneDHCPD, "usb0"}, start: {OneDHCPD, :start_server, ["usb0"]}},
        {VintageNet.Interface.LANConnectivityChecker, "usb0"}
      ],
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, ["usb0"]},
        {:fun, VintageNet.NameResolver, :clear, ["usb0"]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "usb0", "label", "usb0"]},
        {:run, "ip", ["link", "set", "usb0", "down"]}
      ],
      files: [],
      up_cmd_millis: 5000,
      up_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "usb0", "label", "usb0"]},
        {:run, "ip", ["addr", "add", "172.31.246.65/30", "dev", "usb0", "label", "usb0"]},
        {:run, "ip", ["link", "set", "usb0", "up"]},
        {:fun, VintageNet.RouteManager, :clear_route, ["usb0"]},
        {:fun, VintageNet.NameResolver, :clear, ["usb0"]}
      ]
    }

    assert expected == output
  end

  def default_opts() do
    # Use the defaults in mix.exs, but normalize the paths to commands
    Application.get_all_env(:vintage_net)
    |> Keyword.merge(
      bin_chat: "chat",
      bin_dnsd: "dnsd",
      bin_ifdown: "ifdown",
      bin_ifup: "ifup",
      bin_ip: "ip",
      bin_killall: "killall",
      bin_mknod: "mknod",
      bin_pppd: "pppd",
      bin_udhcpc: "udhcpc",
      bin_udhcpd: "udhcpd",
      bin_wpa_supplicant: "wpa_supplicant"
    )
  end
end
