{ config, pkgs, ... }:
let
  src = "/var/lib/demo/repo";
  webroot = "/var/www/demo";
in
{
  services.nginx.virtualHosts.demo = {
    listen = [{ addr = "127.0.0.1"; port = 8081; }];
    root = "${webroot}/current";
    extraConfig = ''
      server_tokens off;
      autoindex off;
    '';
    locations."/" = {
      index = "index.html";
      tryFiles = "$uri $uri/ =404";
    };
  };

  # 서비스 부팅 시 1회 pull, 이후 demo-deploy를 직접 실행해서 수동으로 받아오게 만들 수 있음.
  # git archive를 해서 .git 디렉터리 없이 파일만 받아오도록 만들었음.
  systemd.services.demo-deploy = {
    description = "Pull demo static site from GitHub and swap the served release";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    onFailure = [ "slack-alert@%n.service" ];
    path = with pkgs; [ git openssh gnutar coreutils ];

    # 읽기 전용으로 사용 
    environment.GIT_SSH_COMMAND = "ssh -i ${config.age.secrets.demo-deploy-key.path} -o IdentitiesOnly=yes";
    serviceConfig = {
      Type = "oneshot";
      User = "demo";
      Group = "demo";
      EnvironmentFile = config.age.secrets.demo-env.path;
    };
    script = ''
      set -euo pipefail
      if [ ! -d ${src}/.git ]; then
        git clone "$DEMO_REPO_URL" ${src}
      fi

      git -C ${src} remote set-url origin "$DEMO_REPO_URL"
      git -C ${src} pull --ff-only

      rel="${webroot}/releases/$(git -C ${src} rev-parse --short HEAD)"
      if [ ! -d "$rel" ]; then
        rm -rf "$rel.tmp" && mkdir "$rel.tmp"
        git -C ${src} archive HEAD | tar -x -C "$rel.tmp"
        mv "$rel.tmp" "$rel"
      fi

      touch "$rel"
      ln -sfn "$rel" ${webroot}/current
      ls -1dt ${webroot}/releases/*/ | tail -n +6 | xargs -r rm -rf
    '';
  };

  # github pub key는 고정
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  users.users.demo = {
    isSystemUser = true;
    group = "demo";
  };
  users.groups.demo = { };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "demo-deploy" ''
      exec sudo systemctl start demo-deploy.service
    '')
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/demo 0755 demo demo -"
    "d ${webroot} 0755 demo demo -"
    "d ${webroot}/releases 0755 demo demo -"
  ];
}
