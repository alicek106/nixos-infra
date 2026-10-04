# libvirt + QEMU/KVM for the Windows VMs. See nixos-desktop/VM_PLAN.md.
# KVM (kernel) runs the guest CPU; QEMU emulates the devices; libvirt manages QEMU
# from domain XML files (virsh). Networking is our own br-vm (vm-network.nix),
# not libvirt's built-in networks.
{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm; # host architecture (x86_64) only; smaller than full qemu
      # Run QEMU as the unprivileged qemu-libvirtd user, not root,
      # so a guest that escapes QEMU does not get root on the host.
      runAsRoot = false;
      # Emulated TPM 2.0. Required by Windows 11.
      swtpm.enable = true;
    };

    # Don't start VMs when the host boots. The default ("start") would restart any VM
    # that was running at shutdown, even without autostart.
    onBoot = "ignore";
    # On host shutdown, send the VMs a normal ACPI shutdown. The default ("suspend")
    # saves VM memory to disk, which doesn't work with a passed-through GPU.
    onShutdown = "shutdown";
  };

  # Lets the desktop user run `virsh` against qemu:///system without sudo.
  users.users.desktop.extraGroups = [ "libvirtd" ];
}
