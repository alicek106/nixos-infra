# Minecraft Java server (Fabric, MC 26.3), managed by the nix-minecraft module (flake input).
# Fabric was chosen over Paper for Distant Horizons: the Fabric DH mod is the same jar on the
# server and the clients, so the versions always match. (The Paper DH plugin only supports
# DH 3.1-3.2, but every client DH for MC 26.x is 3.3.)
#
# Not started at boot. It shares the host with win-game, and both need most of the RAM:
#   sudo systemctl start minecraft-server-main     # stop win-game first
#   sudo systemctl stop minecraft-server-main
# Server console (users in the "minecraft" group):
#   tmux -S /run/minecraft/main.sock attach        # detach: Ctrl+b, then d
# World data: /srv/minecraft/main
{ pkgs, tailscaleIPs, ... }:
let
  # Server-side mods, pinned by hash (versions for MC 26.3 from Modrinth).
  # Left out on purpose: C2ME and ScalableLux (alpha builds, risk of broken world generation).
  mods = {
    fabric-api = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/bNnaTiuM/fabric-api-0.161.0%2B26.3.jar";
      sha512 = "ed6b2586d6fde11fde8472f5a527c51e99b67026e46f94d4bfd85e7e28ce5ee299173ee16ad576ceb51f39f98d30a811086a6deb1a86a524859cc16e12da109d";
    };
    # Builds far-away terrain (LODs) on the server and sends it to clients that have DH.
    # Clients need exactly this DH version (3.3.4 for 26.3).
    distanthorizons = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/uCdwusMi/versions/TGgEbP9A/DistantHorizons-3.3.4-26.3-fabric-neoforge.jar";
      sha512 = "0b90b1b08d99974bfc3c8e86b2ceb252e2f91715ed66b925004c28335fb44e1bddbbb6b8043e4d4d53c87ed247789cd1788b1ba4e3f4394efe154e0c59cff236";
    };
    # General game logic optimizations (mobs, blocks, chunk ticking). Vanilla behavior kept.
    lithium = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/xS0Q8LSi/lithium-fabric-0.26.2%2Bmc26.3.jar";
      sha512 = "4d7fee66132eedc71feab9390b92c95d7058edbdad0fecfac1d836a2950b97a7ca463afbede61c7ef361ce65e1f927ab9e89dde5bf2e0e0ce486afb5c5dbee40";
    };
    # Lower memory use.
    ferrite-core = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
      sha512 = "d81fa97e11784c19d42f89c2f433831d007603dd7193cee45fa177e4a6a9c52b384b198586e04a0f7f63cd996fed713322578bde9a8db57e1188854ae5cbe584";
    };
    # Faster networking code.
    krypton = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/fQEb0iXm/versions/UugdIYJw/krypton-0.3.2.jar";
      sha512 = "d1d57ebd41395b75b01f130cd9503eb8d208212424a399ff9f367f50be8fbc1c6472442b33c686e777c3148f6a609520e8fb732c755157c358cb207fd4d1123a";
    };
    # 3D web map of the world, viewed in a browser (config below).
    bluemap = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/swbUV1cr/versions/bbzcTCOs/bluemap-5.28-fabric.jar";
      sha512 = "21978808ee083f6abe06ba23fd0ff6c0e07fcfa7260f3e1cff959a517836e3e71a08a43574a3711ec37456bd6ad9fc1ebaabb736b590ee53f0d79f01637f8b26";
    };
    # Pre-generates chunks ahead of time, so exploring doesn't lag (/chunky commands).
    chunky = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/fALzjamp/versions/4Eotm6ov/Chunky-Fabric-1.5.3.jar";
      sha512 = "b83bfe7b218d0aa6232af977ae741dc1f82b10e50cd12bb759f65cf416b8b62beccb543e587ef0b9670abe03815660f8e091bc6823624d65cf07300571573516";
    };
  };
in
{
  services.minecraft-servers = {
    enable = true;
    eula = true; # Mojang's EULA must be accepted to run a server.

    servers.main = {
      enable = true;
      autoStart = false;
      # MC 26.x needs Java 25. nix-minecraft's Fabric packages use nixpkgs' default
      # jre_headless (Java 21 in 26.05) instead of the Java version Mojang requires, so the
      # server would refuse to start. Override it.
      package = pkgs.fabricServers.fabric-26_3.override { jre_headless = pkgs.jdk25_headless; };

      # Opens the game port (25565/TCP) on all interfaces, for friends outside the tailnet.
      # The router must also forward 25565 to this host.
      openFirewall = true;

      # Paper's recommended G1 flags for MC 26.3 (Aikar's flags). Heap 10G of the host's 15GiB:
      # nothing else runs on the host while the server is up.
      # Xms = Xmx plus AlwaysPreTouch: the whole heap is reserved at start, so it never resizes.
      jvmOpts = [
        "-Xms10G"
        "-Xmx10G"
        "-XX:+UseG1GC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+DisableExplicitGC"
        "-XX:+AlwaysPreTouch"
        "-XX:G1NewSizePercent=30"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:G1HeapRegionSize=8M"
        "-XX:G1ReservePercent=20"
        "-XX:G1HeapWastePercent=5"
        "-XX:G1MixedGCCountTarget=4"
        "-XX:InitiatingHeapOccupancyPercent=15"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:SurvivorRatio=32"
        "-XX:+PerfDisableSharedMem"
        "-XX:MaxTenuringThreshold=1"
      ];

      serverProperties = {
        server-port = 25565;
        motd = "alicek106 server";
        max-players = 10;

        # Only listed players can join. The server is open to the internet, and bots scan for
        # open servers. Add players at runtime from the console: /whitelist add <name>
        white-list = true;
        enforce-whitelist = true;

        # Chunks sent to players. Farther terrain comes from Distant Horizons instead.
        view-distance = 10;
        # Chunks that actually tick (mobs, farms, redstone). The biggest CPU cost, so kept low.
        simulation-distance = 6;

        # Don't fsync every chunk write. Big I/O saving; a crash can lose the last few seconds.
        sync-chunk-writes = false;
        # lz4 instead of deflate for region files: less CPU. btrfs zstd compresses the disk anyway.
        region-file-compression = "lz4";
        # Keep ticking when nobody is online, so chunk pre-generation (Chunky) keeps running.
        pause-when-empty-seconds = -1;
      };

      symlinks = {
        mods = pkgs.linkFarmFromDrvs "mods" (builtins.attrValues mods);
      };

      # Copied (not symlinked) because the mods may rewrite their config files.
      files = {
        # BlueMap won't render until accept-download is true: it downloads the vanilla client
        # jar from Mojang for block textures. Other values are BlueMap's defaults, except
        # 2 render threads (leaves CPU for the game).
        "config/bluemap/core.conf" = pkgs.writeText "core.conf" ''
          accept-download: true
          data: "bluemap"
          render-thread-count: 2
          update-cooldown: 60
          full-update-interval: 1440
          region-file-check-interval: 5
          scan-for-mod-resources: true
          metrics: false
          log: {
            file: "bluemap/logs/debug.log"
            append: false
          }
        '';
        # The map's web server listens only on the tailscale IP: http://100.64.0.4:8100
        # tailscale0 is trusted in the firewall, so it is reachable from the tailnet only.
        "config/bluemap/webserver.conf" = pkgs.writeText "webserver.conf" ''
          enabled: true
          webroot: "bluemap/web"
          ip: "${tailscaleIPs.nixos-desktop}"
          port: 8100
          log: {
            file: "bluemap/logs/webserver.log"
            append: false
          }
        '';
      };
    };
  };

  # Lets the desktop user attach to the server console without sudo.
  users.users.desktop.extraGroups = [ "minecraft" ];
}
