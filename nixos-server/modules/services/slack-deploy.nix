{ config, lib, pkgs, ... }:
# slack /deploy command bot
# permissions: Socket Mode enable, Oauth & Permissions -> commands enable, slash command -> /deploy
let
  # 실행할 system unit. 서비스 추가해야 한다면 여기에 추가할 것.
  # current는 배포된 커밋을 slack에 notify하는 symlink
  targets = {
    demo = { unit = "demo-deploy.service"; current = "/var/www/demo/current"; };
  };
  units = lib.mapAttrsToList (_: t: t.unit) targets;

  bot = pkgs.writers.writePython3Bin "slack-deploy"
    {
      libraries = [ pkgs.python3Packages.slack-bolt ];
      flakeIgnore = [ "E501" ];
    }
    (builtins.readFile ./slack-deploy.py);
in
{
  systemd.services.slack-deploy = {
    description = "Slack /deploy slash command bot (Socket Mode)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    onFailure = [ "slack-alert@%n.service" ];
    environment.DEPLOY_TARGETS = builtins.toJSON targets;
    serviceConfig = {
      ExecStart = lib.getExe bot;
      # SLACK_APP_TOKEN(xapp-), SLACK_BOT_TOKEN(xoxb-)
      EnvironmentFile = config.age.secrets.slack-deploy-env.path;
      User = "slack-deploy";
      Group = "slack-deploy";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  users.users.slack-deploy = {
    isSystemUser = true;
    group = "slack-deploy";
  };
  users.groups.slack-deploy = { };

  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "slack-deploy" &&
          action.lookup("verb") == "start" &&
          ${builtins.toJSON units}.indexOf(action.lookup("unit")) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';
}
