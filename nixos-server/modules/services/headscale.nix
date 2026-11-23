{ config, pkgs, tailscaleIPs, ... }:
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
      # catch all 라우팅은 0.0.0.0 말고도 tailnet ip도 listen하도록 만들어야 444가 정상적으로 내려감
      listenAddresses = config.services.nginx.defaultListenAddresses ++ [ config.homelab.tailnetIP ];
      locations."/".return = "444"; # 평문 HTTP 는 연결만 끊음
    };
    virtualHosts."headscale.alicek106.com" = {
      useACMEHost = "headscale.alicek106.com";
      forceSSL = true;
      # nginx 취약점때문에 비활성화
      http2 = false;
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
          { name = "jenkins.alicek106.net"; type = "A"; value = tailscaleIPs.nixos-desktop; }
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
      # 기본적으로 headscale은 이런 설정이 없어도 노드간 통신은 모두 allow하므로 이 코드는 사실 필요가 없지만
      # nixos-desktop이 10.100.0.0/24 (VM subnet, 브릿지에 묶인 CIDR) 을 모든 tailnet node에게 자동으로 라우팅을 전파하려면
      # 이 설정이 필요하다.
      policy = {
        mode = "file";
        path = toString (
          pkgs.writeText "headscale-acl.json" (
            builtins.toJSON {
              acls = [
                {
                  action = "accept";
                  src = [ "*" ];
                  dst = [ "*:*" ];
                }
              ];
              autoApprovers = {
                # alicek106 user에 대한 노드들은 exitNode, VM subnet route 자동 승인
                routes = {
                  "10.100.0.0/24" = [ "alicek106@" ];
                };
                exitNode = [ "alicek106@" ];
              };
            }
          )
        );
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 3478 41641 ];
}
