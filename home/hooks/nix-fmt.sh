#!/usr/bin/env bash
# PostToolUse hook: auto-format edited .nix files with nixpkgs-fmt.
# Claude Code passes the tool input JSON on stdin → extract file_path.
set -euo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

[ -n "$file" ] || exit 0
case "$file" in
  *.nix) [ -f "$file" ] && nixpkgs-fmt "$file" >/dev/null 2>&1 || true ;;
esac
exit 0
