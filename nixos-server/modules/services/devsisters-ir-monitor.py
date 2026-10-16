#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.request

URL = "https://www.devsisters.com/investors/ir-releases?category=qa&page=1"
STATE_FILE = os.path.join(os.environ.get("STATE_DIRECTORY", "."), "seen.json")


def fetch_list():
    req = urllib.request.Request(
        URL, headers={"User-Agent": "Mozilla/5.0 (devsisters-ir-monitor)"}
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        html = resp.read().decode("utf-8")
    m = re.search(
        r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>',
        html,
        re.DOTALL,
    )
    if not m:
        raise RuntimeError("__NEXT_DATA__ not found in page")
    data = json.loads(m.group(1))
    return data["props"]["pageProps"]["resData"]["list"]


def load_seen():
    try:
        with open(STATE_FILE) as f:
            return set(json.load(f))
    except FileNotFoundError:
        return None


def save_seen(ids):
    with open(STATE_FILE, "w") as f:
        json.dump(sorted(ids), f)


def notify_slack(entry):
    webhook = os.environ.get("SLACK_WEBHOOK_URL")
    if not webhook:
        print("no SLACK_WEBHOOK_URL - skip alert")
        return
    title = entry.get("title", "(제목 없음)")
    date = entry.get("date", "")
    link = "https://www.devsisters.com" + entry.get("link", "")
    text = f"📢 Devsisters IR Q&A 새 글: {title} ({date})\n{link}"
    body = json.dumps({"text": text}).encode("utf-8")
    req = urllib.request.Request(
        webhook, data=body, headers={"Content-Type": "application/json"}
    )
    urllib.request.urlopen(req, timeout=5).read()


def main():
    entries = fetch_list()
    current_ids = {e["query"] for e in entries}
    seen_ids = load_seen()

    if seen_ids is None:
        save_seen(current_ids)
        print(f"first run, baseline saved ({len(current_ids)} entries)")
        return

    new_ids = current_ids - seen_ids
    if new_ids:
        for e in entries:
            if e["query"] in new_ids:
                notify_slack(e)
        print(f"alerted {len(new_ids)} new entries")
    save_seen(current_ids | seen_ids)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
