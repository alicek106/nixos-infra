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
}
