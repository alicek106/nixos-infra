{ config, lib, pkgs, modulesPath, ... }:
{
  # TODO: 실제 설치 시 아래 명령으로 생성된 파일로 교체한다 (disko가 파일시스템은 담당하므로 --no-filesystems).
  #   nixos-generate-config --no-filesystems --root /mnt
  #   cp /mnt/etc/nixos/hardware-configuration.nix nixos-desktop/hardware-configuration.nix
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
