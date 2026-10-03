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
}
