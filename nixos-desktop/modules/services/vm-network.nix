# VM network: an internal bridge (br-vm) that acts as a virtual switch for the VMs.
# The host joins this switch with 10.100.0.1 and becomes the VMs' gateway.
# The physical NIC (enp7s0) is NOT added to the bridge. See nixos-desktop/VM_PLAN.md.
{ ... }:
{
  # Bridge with no physical ports. libvirt plugs each VM's tap device (vnetN) into it.
  networking.bridges.br-vm.interfaces = [ ];

  # Giving the bridge an address also makes the kernel add the route
  # "10.100.0.0/24 dev br-vm", so the host can reach the VMs directly.
  networking.interfaces.br-vm.ipv4.addresses = [
    {
      address = "10.100.0.1";
      prefixLength = 24;
    }
  ];

  # Turn the host into a router.
  # Without this, the kernel drops packets that are not addressed to the host itself.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # Use the native nftables firewall instead of the iptables-based one.
  # NixOS only manages its own tables, so rules added by tailscale stay intact.
  networking.nftables.enable = true;

  # With nftables, tailscale's own rules and the NixOS firewall live in separate chains,
  # and a packet must pass BOTH. So tailscale's ACCEPT alone is no longer enough.
  # Tell the NixOS firewall about tailscale too, to keep the same behavior as before.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  services.tailscale.openFirewall = true; # UDP 41641, for direct peer-to-peer connections

  # NAT for VM traffic going out to the LAN/internet.
  # The home router has no route back to 10.100.0.0/24, so we rewrite the source
  # address to the host's own address on enp7s0 (masquerade = "whatever IP enp7s0 has now").
  networking.nftables.tables.vm-nat = {
    family = "ip";
    content = ''
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        ip saddr 10.100.0.0/24 oifname "enp7s0" masquerade
      }
    '';
  };

  # DHCP server for the VMs. Each VM always gets the same IP, reserved by its MAC.
  # MAC rule: 52:54:00:64:00:<last octet of the IP, in hex>.
  services.dnsmasq = {
    enable = true;
    # DHCP only. Don't point the host's own /etc/resolv.conf at dnsmasq.
    resolveLocalQueries = false;
    settings = {
      port = 0; # disable the DNS server part of dnsmasq
      interface = "br-vm";
      bind-interfaces = true; # never answer on enp7s0 (the home LAN already has a DHCP server)

      # "static": hand out addresses only to the MACs listed in dhcp-host below.
      dhcp-range = "10.100.0.0,static,255.255.255.0,12h";
      dhcp-host = [
        "52:54:00:64:00:0a,10.100.0.10,win-game"
        "52:54:00:64:00:14,10.100.0.20,win-bank"
      ];
      dhcp-option = [
        "option:router,10.100.0.1" # default gateway = the host
        "option:dns-server,192.168.0.1" # home router. dnsmasq's own DNS is off (port = 0)
      ];
      # We are the only DHCP server on br-vm, so answer renewals right away even after a restart.
      dhcp-authoritative = true;
    };
  };

  # Allow DHCP requests (UDP 67) from the VMs, only on br-vm.
  networking.firewall.interfaces.br-vm.allowedUDPPorts = [ 67 ];

  # Announce the VM subnet to the tailnet, so other tailnet devices (e.g. the laptop)
  # can reach 10.100.0.0/24 through this host. headscale auto-approves this route
  # (see nixos-server/modules/services/headscale.nix), so no manual approval step.
  # extraSetFlags (not extraUpFlags) because this node authenticates manually, without
  # an authKeyFile; `tailscale set` applies regardless of how the node was authenticated.
  services.tailscale.extraSetFlags = [ "--advertise-routes=10.100.0.0/24" ];
}
