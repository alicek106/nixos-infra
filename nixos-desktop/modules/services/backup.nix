# tailscale 클라이언트 상태만 S3에 백업한다 (재설치 시 headscale에 재등록 안 해도 되게).
# mkS3BackupPair 팩토리는 nixos-server 와 공유 (../../../modules/mk-s3-backup-pair.nix).
{ config, pkgs, lib, ... }:
let
  mkS3BackupPair =
    import ../../../modules/mk-s3-backup-pair.nix { inherit lib pkgs; }
      {
        bucket = "alicek106-backup";
        cred = config.age.secrets.nixos-credential.path;
      };
in
mkS3BackupPair {
  name = "tailscale";
  mainUnit = "tailscaled.service";
  stateDir = "/var/lib/tailscale";
  sentinel = "/var/lib/tailscale/tailscaled.state";
  # 버킷 경로를 노드별로 분리 (서버와 같은 "tailscale" 서비스 이름을 쓰므로 hostName 으로 구분).
  s3key = "tailscale/${config.networking.hostName}/tailscale-backup.tar.gz";
  extractFlags = "-xzp --numeric-owner";
  user = null;
  backupBuild = ''
    tar -czpf "$tmp/backup.tar.gz" --numeric-owner -C /var/lib/tailscale .
  '';
}
