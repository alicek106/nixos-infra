# GPU passthrough: hand the GTX 1660 SUPER to the win-game VM. See nixos-desktop/VM_PLAN.md.
# The host never uses this GPU; vfio-pci claims it at boot. The host then has no display
# output at all (the Ryzen iGPU is disabled in the BIOS), so this machine is headless.
{ ... }:
{
  boot.kernelParams = [
    # All four functions of the card (IOMMU group 6) are claimed by vfio-pci instead of
    # their usual drivers: GPU (nouveau), HDMI audio, USB-C controller, USB-C UCSI.
    "vfio-pci.ids=10de:21c4,10de:1aeb,10de:1aec,10de:1aed"

    # The 1660S is the boot GPU, so the UEFI firmware leaves a framebuffer in its memory and
    # the kernel's simpledrm/efifb takes it over. That keeps part of the GPU's memory (BAR)
    # busy and the VM fails to get it ("BAR ... can't reserve"). Don't set up that framebuffer.
    "initcall_blacklist=sysfb_init"
  ];

  # Load vfio-pci in the initrd, early, so it grabs the card before any other driver can.
  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];

  # Never load the open-source NVIDIA driver on the host.
  boot.blacklistedKernelModules = [ "nouveau" ];

  # If another driver still grabs a function first (e.g. xhci_pci for the USB-C controller),
  # libvirt's <hostdev managed='yes'> moves it to vfio-pci when the VM starts.

  # Using the GPU on the host later (e.g. CUDA), without a reboot:
  # A PCI device is held by one driver at a time. Move the GPU (01:00.0) from vfio-pci
  # to a host driver at runtime. The VM using it (win-game) must be shut down first.
  #
  #   dev=/sys/bus/pci/devices/0000:01:00.0
  #   echo nouveau | sudo tee $dev/driver_override   # only this driver may take it
  #   echo 0000:01:00.0 | sudo tee $dev/driver/unbind # release it from vfio-pci
  #   sudo modprobe nouveau                           # the blacklist only stops auto-loading
  #   echo 0000:01:00.0 | sudo tee /sys/bus/pci/drivers_probe
  #
  # driver_override matters: without it, vfio-pci would claim the card again (vfio-pci.ids).
  # Pick one host driver and go straight from vfio-pci to it.
  # A driver never takes over a device that another driver already holds.
  # So going nouveau -> nvidia later means repeating all the steps above.
  # For CUDA, use the proprietary driver instead of nouveau ("nvidia" in the commands above).
  # Install it first in nix (NixOS wiki "NVIDIA": hardware.nvidia, videoDrivers), then
  # `nixos-rebuild switch`. No reboot needed: the GPU stays on vfio-pci until you move it.
  # To give the GPU back to the VM, reboot. Switching back and forth at runtime can leave a
  # consumer NVIDIA card in a bad state, and a reboot is the reliable reset.
}
