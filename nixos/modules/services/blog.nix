{ config, pkgs, ... }:
let
  domain = "blog.alicek106.com"; # PoC
  src = "/var/lib/blog";
  webroot = "/var/www/blog";
  tnip = config.homelab.tailnetIP;
in
{
  security.acme.certs.${domain} = {
    dnsProvider = "route53";
    environmentFile = config.age.secrets.nixos-credential.path;
    group = "nginx";
  };

  services.nginx = {
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      useACMEHost = domain;
      forceSSL = true;
      root = "${webroot}/current";
      extraConfig = ''
        server_tokens off;
        autoindex off;
      '';
      locations."/" = {
        index = "index.html";
        tryFiles = "$uri $uri/ =404";
      };

      locations."~* \\.(css|js|woff2?|png|jpe?g|gif|svg|ico)$".extraConfig = ''
        add_header Cache-Control "public, max-age=31536000, immutable";
        add_header X-Content-Type-Options "nosniff" always;
      '';

      locations."~* \\.(html|xml)$".extraConfig = ''
        add_header Cache-Control "public, max-age=0, must-revalidate";
        add_header X-Content-Type-Options "nosniff" always;
      '';
    };

    virtualHosts."editor.alicek106.net" = {
      listen = [{ addr = tnip; port = 80; }];
      locations."/" = {
        proxyPass = "http://${tnip}:4444";
        proxyWebsockets = true;
      };
    };
  };

  services.code-server = {
    enable = true;
    user = "alicek106";
    group = "users";
    host = tnip;
    port = 4444;
    auth = "password";
    extraPackages = with pkgs; [ hugo git ];
    extraArguments = [ src ];
  };

  systemd.services.code-server.serviceConfig.EnvironmentFile =
    config.age.secrets.aliced-env.path;

  systemd.services.blog-build = {
    description = "Build Hugo blog and atomically swap the served release";
    wantedBy = [ "multi-user.target" ];
    after = [ "blog-s3-restore.service" ];
    path = with pkgs; [ hugo coreutils ];
    serviceConfig = {
      Type = "oneshot";
      User = "alicek106";
      Group = "users";
    };
    script = ''
      set -euo pipefail
      rel="${webroot}/releases/rel-$(date +%Y%m%d-%H%M%S)"
      hugo --minify --gc -s ${src} -d "$rel"
      ln -sfn "$rel" ${webroot}/current
      ls -1dt ${webroot}/releases/*/ | tail -n +6 | xargs -r rm -rf
    '';
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "new-post" ''
      set -euo pipefail
      title="''${1:?usage: new-post \"제목\" [dev|essay]}"
      section="''${2:-dev}"
      slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
      cd ${src}
      ${pkgs.hugo}/bin/hugo new "content/$section/$slug/index.md"
      echo "created: ${src}/content/$section/$slug/index.md"
    '')
    (pkgs.writeShellScriptBin "blog-publish" ''
      exec sudo systemctl start blog-build.service
    '')
    (pkgs.writeShellScriptBin "blog-preview" ''
      exec ${pkgs.hugo}/bin/hugo server -D -s ${src} --bind ${tnip} --baseURL "http://${tnip}:1313/"
    '')
  ];

  systemd.tmpfiles.rules = [
    "d ${src} 0755 alicek106 users -"
    "d /var/www 0755 root root -"
    "d ${webroot} 0755 alicek106 users -"
    "d ${webroot}/releases 0755 alicek106 users -"
  ];
}
