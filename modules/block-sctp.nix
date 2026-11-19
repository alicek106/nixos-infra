{ pkgs, ... }:
{
  # nginx 취약점때문에 비활성화
  boot.extraModprobeConfig = ''
    install sctp ${pkgs.coreutils}/bin/false
  '';
}
