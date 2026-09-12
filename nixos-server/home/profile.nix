{ username, homeDirectory }:
{ ... }:
{
  imports = [
    ./claude-code.nix
    ./shell.nix
    ./tools.nix
    ./git.nix
    ./neovim.nix
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "26.05";
}
