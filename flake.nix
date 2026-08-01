{
  description = "alicek106 nixos server configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # 다른 채널이 필요한 경우 유동적으로 추가해서 쓴다.
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

      # 다른 채널이 필요한 경우 유동적으로 추가해서 쓴다.
      channelsOverlay = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit (prev) system;
          config.allowUnfree = true;
        };
      };
    in
    {
      nixosConfigurations.nixos-alicek106 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          ./nixos/disk-config.nix
          ./nixos/configuration.nix
          # 아래의 nixpkgs 라는 키워드는 output의 args로 들어온 nixpkgs와는 관련이 없는, nix에서 자체적으로 정한 키워드임.
          { nixpkgs.overlays = [ channelsOverlay ]; }
          # agenix CLI (시크릿 생성/편집: agenix -e)
          { environment.systemPackages = [ agenix.packages.${system}.default ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # home directory (e.g. ~/.claude/settings.json) 에 파일이 이미 있으면 백업하고 작업한다.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.alicek106 = import ./nixos/home/alicek106.nix;
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
