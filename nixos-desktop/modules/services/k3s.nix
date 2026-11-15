{ ... }:
{
  services.k3s = {
    enable = true;
    disable = [
      "traefik"
      "servicelb"
    ];
    extraFlags = [ "--secrets-encryption" ];
  };

  networking.firewall.interfaces.cni0.allowedTCPPorts = [
    6443
    10250
  ];
}
