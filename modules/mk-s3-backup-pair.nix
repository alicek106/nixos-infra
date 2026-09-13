# S3 백업/복구 systemd 유닛 쌍을 만드는 공용 팩토리.
# restore에 실패하면 mainUnit이 뜨지 않으므로 주의.
# 빈 상태는 백업하지 않는다 (S3 오염 방지, 버킷 버저닝으로도 어차피 복구 가능).
{ lib, pkgs }:
{ bucket # 백업을 저장할 S3 버킷
, cred # AWS 자격증명이 담긴 EnvironmentFile 경로
}:
{ name # "headscale", "gitea" 등
, mainUnit # 이 unit이 성공한 상태여야 이 백업이 진행된다
, stateDir # /var/lib/<x>
, sentinel # 맨 처음 restore 할 때 "restore가 이미 된 상태임" 을 나타내기 위해 저장하는 플래그 파일. 이 파일이 있으면 백업만 하고 복구는 하지 않는다.
, s3key # 버킷에서 사용할 restore file 키
, extractFlags # 추출 tar 플래그
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
    requiredBy = [ mainUnit ];
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
        echo "no S3 backup (404) - fresh start (nothing to restore)"; exit 0
      else
        echo "S3 check failed (not 404) - refusing to start with empty state:"; cat "$tmp/err"; exit 1
      fi
      echo "empty state + S3 backup exists -> restoring…"
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
        echo "no local ${name} state (${sentinel} absent) - refuse to back up (avoid clobbering S3)"; exit 1
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
}
