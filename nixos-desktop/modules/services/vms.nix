# Registers the VMs with libvirt from the domain XML files in nixos-desktop/vms/.
# Defining a VM only registers it; it does not start it (no autostart, see VM_PLAN.md).
{ config, pkgs, ... }:
let
  # Fill in nix store paths that can't be written into the XML file directly.
  # replaceVars fails the build if any @placeholder@ is left unreplaced.
  winBankXml = pkgs.replaceVars ../../vms/win-bank.xml {
    # pkgs.virtio-win is the unpacked driver directory (the build result).
    # Its .src attribute is the raw input it was built from: the original virtio-win.iso,
    # downloaded with a pinned hash. The VM needs an ISO to attach as a CD, so use .src.
    virtioWinIso = "${pkgs.virtio-win.src}";
  };

  winGameXml = pkgs.replaceVars ../../vms/win-game.xml {
    virtioWinIso = "${pkgs.virtio-win.src}";
    # UEFI firmware with Secure Boot. The .ms VARS template has the Microsoft keys enrolled.
    ovmfCode = "${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd";
    ovmfVarsMs = "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.ms.fd";
  };
in
{
  systemd.services.libvirt-define-vms = {
    description = "Define libvirt VMs from the repo's domain XML";
    requires = [ "libvirtd.service" ];
    after = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.virtualisation.libvirtd.package pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Re-runs on `nixos-rebuild switch` whenever the XML changes (its store path is in this script).
    script = ''
      # Create a disk image only if it doesn't exist yet. truncate makes a sparse file:
      # full apparent size, but it uses no space until Windows writes to it.
      # It inherits nodatacow (+C) from /var/lib/libvirt/images.
      make_disk() {
        if [ ! -e "$1" ]; then
          truncate -s "$2" "$1"
        fi
      }
      make_disk /var/lib/libvirt/images/win-bank.raw 64G
      make_disk /var/lib/libvirt/images/win-game.raw 100G

      virsh --connect qemu:///system define ${winBankXml}
      virsh --connect qemu:///system define ${winGameXml}
    '';
  };
}
