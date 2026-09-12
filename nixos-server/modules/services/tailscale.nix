{ lib, ... }:
{
  options.homelab.tailnetIP = lib.mkOption {
    type = lib.types.str;
    default = "100.64.0.2";
    description = "fixed IP of this nisos server";
  };

  config = {
    # tailscale client enable
    services.tailscale.enable = true;

    # 아직 IP가 안떴어도 (즉 tailscale이 안붙었어도) 없는 IP로 바인딩하게 해주는 옵션임
    boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;
  };
}
