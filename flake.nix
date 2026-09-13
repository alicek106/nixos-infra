{
  description = "alicek106 nixos server configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, home-manager, agenix }:
    let
      system = "x86_64-linux";

      channelsOverlay = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit (prev) system;
          config.allowUnfree = true;
        };
      };

      tailscaleIPs = {
        alicek106-m4 = "100.64.0.1"; # not used here, not nix managed
        nixos-alicek106 = "100.64.0.2"; # N100 server
        devsisters-linux = "100.64.0.3"; # not used, not nix managed
        nixos-desktop = "100.64.0.4"; # desktop server. proxmox
      };
    in
    {
      nixosConfigurations.nixos-server = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit tailscaleIPs; };
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          ./nixos-server/disk-config.nix
          ./nixos-server/configuration.nix
          # 아래의 nixpkgs 라는 키워드는 output의 args로 들어온 nixpkgs와는 관련이 없는, nix에서 자체적으로 정한 키워드임.
          { nixpkgs.overlays = [ channelsOverlay ]; }
          { environment.systemPackages = [ agenix.packages.${system}.default ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # home directory (e.g. ~/.claude/settings.json) 에 파일이 이미 있으면 백업하고 작업한다.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.alicek106 = import ./home/profile.nix {
              username = "alicek106";
              homeDirectory = "/home/alicek106";
            };
          }
        ];
      };

      nixosConfigurations.nixos-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit tailscaleIPs; };
        modules = [
          disko.nixosModules.disko
          ./nixos-desktop/disk-config.nix
          ./nixos-desktop/configuration.nix
          { nixpkgs.overlays = [ channelsOverlay ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.desktop = import ./home/profile.nix {
              username = "desktop";
              homeDirectory = "/home/desktop";
            };
          }
        ];
      };

      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./installer/installer.nix ];
      };

      packages.${system}.disko = disko.packages.${system}.disko;
    };
}
