# restore에 실패하면 서비스가 뜨지 않으므로 주의
# 빈 상태도 업로드 하지 못하도록 했음 (s3에 버킷 버저닝 되어있으니 빈 상태로 업로드해도 복구는 가능할듯)
# TODO: gitea 백업은 tmpfs에서 하므로, 규모가 커지면 메모리가 부족할 수도 있으나 당장 신경쓸건 아닌듯.
{ config, pkgs, lib, ... }:
let
  mkS3BackupPair =
    import ../../../modules/mk-s3-backup-pair.nix { inherit lib pkgs; }
      {
        bucket = "alicek106-backup";
        cred = config.age.secrets.nixos-credential.path;
      };
in
lib.mkMerge [
  (mkS3BackupPair {
    name = "headscale";
    mainUnit = "headscale.service";
    stateDir = "/var/lib/headscale";
    sentinel = "/var/lib/headscale/db.sqlite";
    s3key = "headscale/headscale-backup.tar.gz";
    extractFlags = "-xz";
    user = "headscale";
    backupPath = with pkgs; [ sqlite ];
    backupBuild = ''
      sqlite3 /var/lib/headscale/db.sqlite ".backup '$tmp/db.sqlite'"
      cp /var/lib/headscale/noise_private.key "$tmp/noise_private.key"
      tar -czf "$tmp/backup.tar.gz" -C "$tmp" db.sqlite noise_private.key
    '';
  })

  (mkS3BackupPair {
    name = "gitea";
    mainUnit = "podman-gitea.service";
    stateDir = "/var/lib/gitea";
    sentinel = "/var/lib/gitea/gitea/gitea.db";
    s3key = "gitea/gitea-backup.tar.gz";
    extractFlags = "-xzp --numeric-owner";
    user = null; # root
    backupPath = with pkgs; [ sqlite ];
    backupBuild = ''
      cp -a /var/lib/gitea "$tmp/tree"
      sqlite3 /var/lib/gitea/gitea/gitea.db ".backup '$tmp/tree/gitea/gitea.db'"
      rm -f "$tmp/tree/gitea/gitea.db-wal" "$tmp/tree/gitea/gitea.db-shm"
      tar -czpf "$tmp/backup.tar.gz" --numeric-owner -C "$tmp/tree" .
    '';
  })

  (mkS3BackupPair {
    name = "tailscale";
    mainUnit = "tailscaled.service";
    stateDir = "/var/lib/tailscale";
    sentinel = "/var/lib/tailscale/tailscaled.state";
    s3key = "tailscale/${config.networking.hostName}/tailscale-backup.tar.gz";
    extractFlags = "-xzp --numeric-owner";
    user = null;
    backupBuild = ''
      tar -czpf "$tmp/backup.tar.gz" --numeric-owner -C /var/lib/tailscale .
    '';
  })

  (mkS3BackupPair {
    name = "blog";
    mainUnit = "blog-build.service";
    stateDir = "/var/lib/blog";
    sentinel = "/var/lib/blog/hugo.toml";
    s3key = "blog/blog-source.tar.gz";
    extractFlags = "-xzp";
    user = null;
    backupBuild = ''
      tar -czp -f "$tmp/backup.tar.gz" \
        --exclude=./public --exclude=./resources --exclude=./.hugo_build.lock --exclude=./.git \
        -C /var/lib/blog .
    '';
  })
]
