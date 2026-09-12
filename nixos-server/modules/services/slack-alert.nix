{ config, pkgs, ... }:
# 다른 서비스에서 가져다 쓰면 된다.
{
  systemd.services."slack-alert@" = {
    description = "Send Slack alert that %i failed";
    path = with pkgs; [ curl jq ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "-${config.age.secrets.slack-webhook.path}";
    };
    scriptArgs = "%i";
    script = ''
      unit="$1"
      [ -n "''${SLACK_WEBHOOK_URL:-}" ] || { echo "no SLACK_WEBHOOK_URL — skip alert"; exit 0; }
      payload=$(jq -n --arg t "🚨 [${config.networking.hostName}] systemd 유닛 실패: $unit" '{text: $t}')
      curl -s --max-time 5 -H 'Content-Type: application/json' -d "$payload" "$SLACK_WEBHOOK_URL" >/dev/null || true
    '';
  };
}
