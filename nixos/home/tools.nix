{ pkgs, ... }:
{
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat.enable = true;

  programs.tmux = {
    enable = true;
  };

  home.packages = with pkgs; [
    ripgrep
    fd
    tree
    wget
    curl
    unzip
    gnupg
    findutils
    gawk
    gnused
    watch
    htop
    gh
    nixpkgs-fmt
    nodejs_24
    python312
    python312Packages.pip
  ];
}
