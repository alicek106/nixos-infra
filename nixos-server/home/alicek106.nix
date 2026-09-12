{ ... }:
{
  imports = [
    ./claude-code.nix
    ./shell.nix
    ./tools.nix
    ./git.nix
    ./neovim.nix
  ];

  home.username = "alicek106";
  home.homeDirectory = "/home/alicek106";
  home.stateVersion = "26.05";
}
