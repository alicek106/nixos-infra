# restore에 실패하면 서비스가 뜨지 않으므로 주의
# 빈 상태도 업로드 하지 못하도록 했음 (s3에 버킷 버저닝 되어있으니 빈 상태로 업로드해도 복구는 가능할듯)
# TODO: gitea 백업은 tmpfs에서 하므로, 규모가 커지면 메모리가 부족할 수도 있으나 당장 신경쓸건 아닌듯.
{ config, pkgs, lib, ... }:
let
  bucket = "alicek106-backup";
  cred = config.age.secrets.nixos-credential.path;

  mkS3BackupPair =
    { name # "headscale" | "gitea"
    , mainUnit # 이 상태에 의존하는 본체 유닛
    , stateDir # /var/lib/<x>
    , sentinel # 존재 시 "상태 있음" (복원 skip / 백업 허용 조건)
    , s3key # 버킷에서 사용할 키
    , extractFlags # 추출 tar 플래그 (headscale: -xz / gitea: -xzp --numeric-owner)
    , backupBuild # $tmp/backup.tar.gz 를 만드는 셸 (서비스별)
    , backupPath ? [ ] # 백업에 필요한 추가 pkgs (e.g. : sqlite)
    , user ? null # null = root
    }:
    let
      onFailure = [ "slack-alert@%n.service" ];
      s3tools = with pkgs; [ awscli2 coreutils gnutar gzip ];
    in
    {
      systemd.services."${name}-s3-restore" = {
        description = "Restore ${name} state from S3 if local state is empty";
        before = [ mainUnit ];
        requiredBy = [ mainUnit ]; # 복원 실패 → 본체 기동 차단
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        inherit onFailure;
        path = s3tools;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PrivateTmp = true;
          EnvironmentFile = cred;
        } // lib.optionalAttrs (user != null) {
          User = user;
          Group = user;
          StateDirectory = name; # /var/lib/<name> 를 <user> 소유로 생성한다
        };
        script = ''
          set -euo pipefail
          if [ -e "${sentinel}" ]; then
            echo "${name} state present — skip restore"; exit 0
          fi
          tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
          # 404는 완전히 서버를 새로 설치하는 것에 해당 (실제론 해당 없음, 이미 초기화 완료 했으니..)
          if aws s3api head-object --bucket ${bucket} --key ${s3key} >/dev/null 2>"$tmp/err"; then
            :
          elif grep -qE '\(404\)|Not Found' "$tmp/err"; then
            echo "no S3 backup (404) — fresh start (nothing to restore)"; exit 0
          else
            echo "S3 check failed (not 404) — refusing to start with empty state:"; cat "$tmp/err"; exit 1
          fi
          echo "empty state + S3 backup exists → restoring…"
          mkdir -p ${stateDir}
          aws s3 cp s3://${bucket}/${s3key} "$tmp/state.tar.gz"
          gzip -t "$tmp/state.tar.gz"
          tar ${extractFlags} -f "$tmp/state.tar.gz" -C ${stateDir}
          echo "${name} state restored from S3"
        '';
      };

      systemd.services."${name}-s3-backup" = {
        description = "Backup ${name} state to S3";
        inherit onFailure;
        path = s3tools ++ backupPath;
        serviceConfig = {
          Type = "oneshot";
          PrivateTmp = true;
          EnvironmentFile = cred;
        };
        script = ''
          set -euo pipefail
          if [ ! -e "${sentinel}" ]; then
            echo "no local ${name} state (${sentinel} absent) — refuse to back up (avoid clobbering S3)"; exit 1
          fi
          tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
          ${backupBuild}
          gzip -t "$tmp/backup.tar.gz" # 업로드 전 검증
          aws s3 cp "$tmp/backup.tar.gz" s3://${bucket}/${s3key}
          echo "${name} backed up to s3://${bucket}/${s3key}"
        '';
      };

      systemd.timers."${name}-s3-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true; # 껐다 켜도 놓친 백업 따라잡도록 함
          RandomizedDelaySec = "1h";
        };
      };
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

  # tailscaled.state = 이 서버의 tailnet 노드 정체성(개인키).
  # 이걸 복원하면 재설치 후에도 tailscaled 가 "같은 노드"로 자동 재접속 → 같은 tailnet IP 유지.
  # (백업 안 하면 재설치마다 새 노드로 등록되어 IP 가 표류함 — headscale 은 set-ip 가 없고 IP 를 단조 할당)
  (mkS3BackupPair {
    name = "tailscale";
    mainUnit = "tailscaled.service";
    stateDir = "/var/lib/tailscale";
    sentinel = "/var/lib/tailscale/tailscaled.state";
    s3key = "tailscale/tailscale-backup.tar.gz";
    extractFlags = "-xzp --numeric-owner"; # root 소유 보존
    user = null; # root
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
