{ config, ... }:
{
  # --- TLS: Let's Encrypt DNS-01 via Route53 ---
  security.acme = {
    acceptTerms = true;
    defaults.email = "alice_k106@naver.com";
    certs."headscale.alicek106.com" = {
      dnsProvider = "route53";
      environmentFile = config.age.secrets.nixos-credential.path;
      group = "nginx"; # nginx 가 인증서를 읽을 수 있게 함
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    # catch-all: 이상한걸로 오는 요청은 모두 여기로 빠진다.
    virtualHosts."_" = {
      default = true;
      rejectSSL = true;
      locations."/".return = "444"; # 평문 HTTP 는 연결만 끊음
    };
    virtualHosts."headscale.alicek106.com" = {
      useACMEHost = "headscale.alicek106.com";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8085";
        proxyWebsockets = true; # headscale long-poll (Upgrade/Connection 헤더)
        extraConfig = ''
          proxy_buffering off;
        '';
      };
    };
  };

  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = 8085;
    settings = {
      server_url = "https://headscale.alicek106.com";
      dns = {
        magic_dns = true;
        base_domain = "alicek106.net";
        nameservers.global = [ "1.1.1.1" "8.8.8.8" ];
        extra_records = [
          { name = "diary.alicek106.net"; type = "A"; value = config.homelab.tailnetIP; }
          { name = "gitea.alicek106.net"; type = "A"; value = config.homelab.tailnetIP; }
          { name = "editor.alicek106.net"; type = "A"; value = config.homelab.tailnetIP; } # temp
        ];
      };
      # TODO: 나중에 STUN, 릴레이에 쓰이는 서버는 별도로 구축한다.
      derp = {
        urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
        auto_update_enabled = true;
        update_frequency = "24h";
      };
      database = {
        type = "sqlite";
        sqlite.path = "/var/lib/headscale/db.sqlite";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 3478 41641 ];
}
