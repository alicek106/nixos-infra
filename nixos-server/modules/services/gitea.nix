{ config, ... }:
{
  virtualisation.oci-containers.containers.gitea = {
    image = "docker.io/gitea/gitea:1.24.7@sha256:918955f16b1e91732af6c449bb2db3a34271748dbed1ccfbae48f8a2fb5480b8";
    volumes = [ "/var/lib/gitea:/data" ];

    # TODO: non-root로 변경
    user = "root";
    environment = {
      USER_UID = "1000";
      USER_GID = "1000";
      GITEA__server__ROOT_URL = "http://gitea.alicek106.net/";
      GITEA__server__DOMAIN = "gitea.alicek106.net";
    };

    ports = [ "${config.homelab.tailnetIP}:3000:3000" ];
  };

  services.nginx.virtualHosts."gitea.alicek106.net" = {
    listen = [{ addr = config.homelab.tailnetIP; port = 80; }];
    locations."/" = {
      proxyPass = "http://${config.homelab.tailnetIP}:3000";
      proxyWebsockets = true; # gitea 일부 기능(SSE/live) 대비..라곤 하는데 잘 이해는 가지 않음.
    };
  };
}
