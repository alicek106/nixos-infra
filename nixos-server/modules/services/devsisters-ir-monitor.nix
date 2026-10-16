{ config, pkgs, ... }:
{
  systemd.services.devsisters-ir-monitor = {
    description = "Devsisters IR Q&A 신규 글 감지 -> Slack 알림";
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      StateDirectory = "devsisters-ir-monitor";
      EnvironmentFile = "-${config.age.secrets.slack-webhook.path}";
      ExecStart = "${pkgs.python3}/bin/python3 ${./devsisters-ir-monitor.py}";
    };
  };

  systemd.timers.devsisters-ir-monitor = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "1m";
      Unit = "devsisters-ir-monitor.service";
    };
  };
}
