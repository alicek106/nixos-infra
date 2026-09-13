{ config, lib, pkgs, tailscaleIPs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../modules/shared-secrets.nix
    ../modules/slack-alert.nix
    ./modules/services/backup.nix
    (import ../modules/tailscale-client.nix { hostIP = tailscaleIPs.nixos-desktop; })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-desktop";
  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.useDHCP = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;
  zramSwap.enable = true;

  users.users.desktop = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106"
    ];
  };

  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
    settings.KexAlgorithms = [
      "mlkem768x25519-sha256"
      "sntrup761x25519-sha512@openssh.com"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    jq
  ];

  system.stateVersion = "26.05";
  security.sudo.wheelNeedsPassword = false;

  programs.git = {
    enable = true;
    config = {
      safe.directory = [ "/home/desktop/nixos-server" ];
    };
  };
}
