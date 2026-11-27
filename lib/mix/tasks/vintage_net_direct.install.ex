# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.VintageNetDirect.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc() do
    "Installs vintage_net_direct in your Nerves project."
  end

  @spec example() :: String.t()
  def example() do
    "mix igniter.install vintage_net_direct"
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    This adds a USB gadget network interface to VintageNet's configuration in
    `config/target.exs`:

    ```elixir
    config :vintage_net,
      config: [
        {"usb0", %{type: VintageNetDirect}}
      ]
    ```

    VintageNet's base configuration is added if the project doesn't have it.
    Other network interfaces are kept and if the interface is already
    configured, it's left as it is.

    If the project doesn't have a `config/target.exs`, the configuration is
    written to `config/config.exs`.

    ## Example

    ```bash
    #{example()}
    ```

    ## Options

    * `--direct-ifname` - The name of the network interface to configure.
      Defaults to `usb0`, the first USB gadget Ethernet interface.
    """
  end
end

if Code.ensure_loaded?(Igniter) and Code.ensure_loaded?(VintageNet.Generator) do
  defmodule Mix.Tasks.VintageNetDirect.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Project.Deps
    alias VintageNet.Generator

    @default_ifname "usb0"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :vintage_net_direct,
        example: __MODULE__.Docs.example(),
        schema: [direct_ifname: :string],
        defaults: [direct_ifname: @default_ifname]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      ifname = igniter.args.options[:direct_ifname]

      if valid_ifname?(ifname) do
        path = "config/#{Generator.config_file(igniter)}"
        before = content(igniter, path)

        igniter =
          igniter
          |> restrict_dep_to_targets()
          |> Generator.add_interface(ifname, %{type: VintageNetDirect})

        # Only tell the user about the interface when it was added. If it was
        # already configured, there's nothing new to say.
        if interface_added?(before, content(igniter, path), ifname) do
          igniter
          |> add_interface_notice(ifname, path)
          |> maybe_add_not_nerves_notice(path)
        else
          igniter
        end
      else
        Igniter.add_issue(igniter, """
        vintage_net_direct: invalid --direct-ifname #{inspect(ifname)}.

        Pass a network interface name like usb0. Interface names are 1 to 15
        characters and can't contain spaces or slashes.
        """)
      end
    end

    # Keeps vintage_net_direct off the host when the project restricts other
    # dependencies to its targets. See VintageNet.Generator.
    defp restrict_dep_to_targets(igniter) do
      Generator.restrict_dep_to_targets(igniter, :vintage_net_direct)
    end

    # These are the Linux rules for network interface names
    defp valid_ifname?(ifname) do
      ifname =~ ~r/\A[^\s\/:]{1,15}\z/ and ifname not in [".", ".."]
    end

    defp content(igniter, path) do
      if Igniter.exists?(igniter, path) do
        igniter = Igniter.include_existing_file(igniter, path)

        case Rewrite.source(igniter.rewrite, path) do
          {:ok, source} -> Rewrite.Source.get(source, :content)
          _ -> nil
        end
      end
    end

    # Adding the interface is the only change that puts the interface name in
    # a file that didn't have it or adds another mention of it.
    defp interface_added?(before, now, ifname) do
      mentions(now, ifname) > mentions(before, ifname)
    end

    defp mentions(nil, _ifname), do: 0

    defp mentions(content, ifname) do
      length(String.split(content, inspect(ifname))) - 1
    end

    defp add_interface_notice(igniter, ifname, path) do
      Igniter.add_notice(igniter, """
      vintage_net_direct: #{inspect(ifname)} was added to the network interfaces in #{path}.

      * The device needs to support USB gadget mode and be connected to your
        computer through its USB gadget (OTG) port. Examples are the Raspberry
        Pi Zero and 3 A+ and the BeagleBone boards. The configuration is unused
        on devices that don't have a #{inspect(ifname)} interface.
      * IP addresses are assigned automatically. They're computed from the
        device's hostname and the interface name, so give devices unique
        hostnames if you connect more than one to a computer. The official
        Nerves systems do this by default.
      #{mdns_notice(igniter)}
      """)
    end

    defp mdns_notice(igniter) do
      if Deps.has_dep?(igniter, :mdns_lite) or Deps.has_dep?(igniter, :nerves_pack) do
        """
        * Use the hostnames that mdns_lite advertises to connect to the device.
          E.g., `ssh nerves.local`.
        """
      else
        """
        * The easiest way to find the device from your computer is by its mDNS
          name. E.g., `ssh nerves.local`. Add `mdns_lite` or `nerves_pack` to
          the project for this.
        """
      end
      |> String.trim_trailing()
    end

    defp maybe_add_not_nerves_notice(igniter, "config/target.exs"), do: igniter

    defp maybe_add_not_nerves_notice(igniter, path) do
      Igniter.add_notice(igniter, """
      vintage_net_direct: config/target.exs was not found, so the network
      configuration was added to #{path}.

      VintageNet is meant for Nerves devices and these defaults assume a
      Nerves project. If this project also runs on your computer, move the
      configuration to where it only applies to the device.
      """)
    end
  end
else
  defmodule Mix.Tasks.VintageNetDirect.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      if Code.ensure_loaded?(Igniter) do
        Mix.shell().error("""
        The task 'vintage_net_direct.install' requires a version of vintage_net that has
        `VintageNet.Generator`. Please update vintage_net and try again.
        """)
      else
        Mix.shell().error("""
        The task 'vintage_net_direct.install' requires igniter. Please install igniter and try again.

        For more information, see: https://igniter.hexdocs.pm/readme.html#installation
        """)
      end

      exit({:shutdown, 1})
    end
  end
end
