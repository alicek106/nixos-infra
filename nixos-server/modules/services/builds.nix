{ config, pkgs, ... }:
let
  host = "builds.alicek106.com";
  webroot = "/var/www/builds";
  user = "ios-build-publish";

  publish = pkgs.writeShellApplication {
    name = "ios-build-publish";
    runtimeInputs = with pkgs; [ coreutils curl findutils gnugrep gnused gnutar jq util-linux ];
    runtimeEnv = {
      BUILDS_ROOT = webroot;
      PUBLIC_URL = "https://${host}";
      WEBHOOK_FILE = config.age.secrets.slack-webhook-ios-build.path;
      KEEP_RELEASES = "10";
    };
    text = builtins.readFile ./builds-publish.sh;
  };

  # Content types Apple documents for over-the-air installs.
  staticFiles = ''
    types {
      text/html html;
      text/xml plist;
      application/octet-stream ipa;
    }
    add_header Cache-Control "no-cache";
  '';
in
{
  security.acme.certs.${host} = {
    dnsProvider = "route53";
    environmentFile = config.age.secrets.nixos-credential.path;
    group = "nginx";
  };

  users.users.${user} = {
    isSystemUser = true;
    group = user;
  };
  users.groups.${user} = { };

  # NOTE: 이것만 선언해도 자동으로 fcgiwrap-builds systemd service가 생성됨
  # systemd 서비스 이름 규칙은 fcgiwrap-<name> 이다. 따라서 fcgiwrap-builds가 됨.
  services.fcgiwrap.instances.builds = {
    process.user = user;
    process.group = user;
    socket.user = config.services.nginx.user;
    socket.group = config.services.nginx.group;
  };

  # publish를 하는 CGI는 반드시 webroot 하위의 디렉터리에만 파일을 쓸 수 있도록 만듦.
  systemd.services.fcgiwrap-builds.serviceConfig = {
    ProtectSystem = "strict";
    ReadWritePaths = [ webroot ];
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
  };

  # IPA를 포함한 tar 번들 upload용 vhost
  services.nginx.virtualHosts.${host} = {
    listen = [{ addr = config.homelab.tailnetIP; port = 443; ssl = true; }];
    onlySSL = true;
    useACMEHost = host;
    root = webroot;
    locations."= /".return = "302 /current/";
    locations."/current/".extraConfig = staticFiles;
    locations."/releases/".extraConfig = staticFiles;

    # publish는 같은 tailnet에서만 호출할 수 있도록 nginx 레이어에서 미리 막아두기
    # 생각해보니 프로비저닝 프로파일을 어차피 아이폰에서 검증하므로 악성 액션은 불가능할 것 같긴 하지만
    # tailnet 노드중 하나가 침해되어 malicious한 파일을 upload를 하게 될 때도, cgi에서 슬랙으로 바로 알람을 보내니 어차피 감지할 수 있을듯.
    locations."/publish/" = {
      fastcgiParams.SCRIPT_FILENAME = "${publish}/bin/ios-build-publish";
      extraConfig = ''
        allow 100.64.0.0/10;
        deny all;
        client_max_body_size 256m;
        fastcgi_pass unix:${config.services.fcgiwrap.instances.builds.socket.address};
      '';
    };
    locations."/".return = "404";
  };

  systemd.tmpfiles.rules = [
    "d ${webroot} 0755 ${user} ${user} -"
    "d ${webroot}/releases 0755 ${user} ${user} -"
    "d ${webroot}/.incoming 0700 ${user} ${user} -"
  ];
}
