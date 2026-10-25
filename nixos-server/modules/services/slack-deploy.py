import json
import os
import subprocess

from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler

# {"demo": {"unit": "demo-deploy.service", "current": "/var/www/demo/current"}}
TARGETS = json.loads(os.environ["DEPLOY_TARGETS"])

app = App(token=os.environ["SLACK_BOT_TOKEN"])


@app.command("/deploy")
def deploy(ack, command, respond):
    name = command.get("text", "").strip()
    target = TARGETS.get(name)
    if target is None:
        ack(f"사용법: /deploy <{'|'.join(sorted(TARGETS))}>")
        return

    ack(f"`{name}` 배포 시작")

    result = subprocess.run(
        ["systemctl", "start", target["unit"]],
        capture_output=True,
        text=True,
    )
    user = f"<@{command['user_id']}>"
    if result.returncode == 0:
        rev = os.path.basename(os.readlink(target["current"]))
        respond(response_type="in_channel", text=f"✅ `{name}` 배포 완료 `{rev}` (by {user})")
    else:
        err = result.stderr.strip() or f"exit {result.returncode}"
        respond(response_type="in_channel", text=f"❌ `{name}` 배포 실패 (by {user})\n```{err}```")


if __name__ == "__main__":
    SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"]).start()
