{ config, lib, pkgs, tailscaleIPs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ../modules/shared-secrets.nix
    ./modules/services/aliced.nix
    ./modules/services/gitea.nix
    ./modules/services/headscale.nix
    ./modules/services/backup.nix
    ./modules/services/ddns.nix
    ../modules/slack-alert.nix
    ./modules/services/blog.nix
    (import ../modules/tailscale-client.nix { hostIP = tailscaleIPs.nixos-alicek106; })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-alicek106";
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

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;
  zramSwap.enable = true;

  users.users.alicek106 = {
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
    awscli2
  ];

  system.stateVersion = "26.05";
  security.sudo.wheelNeedsPassword = false;

  programs.git = {
    enable = true;
    config = {
      safe.directory = [ "/home/alicek106/nixos-server" ];
    };
  };
}
