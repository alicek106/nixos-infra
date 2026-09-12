{ config, ... }:
{
  virtualisation.oci-containers = {
    backend = "podman";
    containers.aliced = {
      image = "public.ecr.aws/o5v4y7w2/diary@sha256:f69e29b2dab4d47ea80512def64f3c49481b45cd34e24496ff0aba1cd7332bed";

      environmentFiles = [
        config.age.secrets.aliced-env.path
        config.age.secrets.nixos-credential.path
      ];

      environment = {
        USERNAME = "alicek106";
        PORT = "80";
        DATA_FILESYSTEM_PATH = "/data";
        ATTACHMENT_FILESYSTEM_PATH = "/data/attachments";
        NOTES_PER_PAGE = "10";
        BACKUP_ENABLED = "true";
        S3_BUCKET_NAME = "alicek106-backup";
        S3_BACKUP_PREFIX = "aliced/";
      };

      volumes = [ "/var/lib/aliced/data:/data" ];
      user = "root";
      ports = [ "${config.homelab.tailnetIP}:8080:80" ];
    };
  };

  # TODO: non-root로 실행 필요
  systemd.tmpfiles.rules = [
    "d /var/lib/aliced 0700 root root -"
    "d /var/lib/aliced/data 0700 root root -"
    "d /var/lib/aliced/data/attachments 0700 root root -"
  ];

  # headscale extra_records로 설정되는 도메인
  services.nginx.virtualHosts."diary.alicek106.net" = {
    listen = [{ addr = config.homelab.tailnetIP; port = 80; }];
    locations."/".proxyPass = "http://${config.homelab.tailnetIP}:8080";
  };
}
