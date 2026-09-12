#!/usr/bin/env bash
# Stop hook: on finish, mechanically detect "non-reproducible smells" in the git diff and warn (non-blocking).
# Only checks high-confidence patterns, and only newly added nix changes. Harmless even on false positives.
# (do not use set -e — a grep no-match returns exit 1, which must not abort us early)
set -uo pipefail

# pass silently if no nix files changed
changed=$( { git diff --name-only HEAD; git diff --name-only --cached; } 2>/dev/null )
printf '%s\n' "$changed" | grep -q '\.nix$' || exit 0

# smell-check only the added (+) lines
added=$( { git diff HEAD -- '*.nix'; git diff --cached -- '*.nix'; } 2>/dev/null \
         | grep -E '^\+' | grep -vE '^\+\+\+' )

smells=""
printf '%s\n' "$added" | grep -qE 'uvx|npx .*@latest|pip install|curl .*\| *sh' \
  && smells="${smells}\n  - runtime download (uvx/npx@latest/pip/curl|sh) — pin it as a nix package"
if printf '%s\n' "$added" | grep -qE 'fetch(url|git|FromGitHub)' \
   && ! printf '%s\n' "$added" | grep -qE 'hash|sha256'; then
  smells="${smells}\n  - fetch* without a hash — pin hash/sha256"
fi
printf '%s\n' "$added" | grep -qE '/(home|Users)/[a-zA-Z]' \
  && smells="${smells}\n  - hardcoded absolute home path — prefer config.home.homeDirectory etc."

[ -z "$smells" ] && exit 0

# if README was not also edited, remind about documentation
note=""
printf '%s\n' "$changed" | grep -q 'README.md' \
  || note="\n  → if this is non-reproducible, it MUST be documented in README.md."

printf '⚠️  Reproducibility check (auto): these patterns were detected in the nix changes:%b%b\n' "$smells" "$note" >&2
exit 0
