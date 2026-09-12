---
name: nix-change-review
description: Use when creating or modifying any Nix code in this repo (*.nix files, flake.nix, home-manager modules under home/, package derivations, configuration.nix). Reviews the change for reproducibility, project conventions/best-practices, and README documentation duties before finishing.
---

# Nix change review (nix-change-review)

When creating or modifying nix code in this repo (`nixos-server`), self-check the following **before
finishing**. The repo's guiding principles are in `CLAUDE.md` ("Design principles"): guarantee
reproducibility / non-reproducible items go in the README / best-practice + simplicity.

## 1. Reproducibility (most important)
Installing on a new machine with only this repo must produce an identical result. Check that none of
these "non-reproducible smells" are present:
- `fetchurl`/`fetchFromGitHub`/`fetchgit` without a hash (always pin `hash`/`sha256`)
- runtime downloads: `uvx`, `npx ... @latest`, `pip install`, `curl | sh`, etc. (→ pin as a nix package)
- non-deterministic inputs like `builtins.currentTime`, `builtins.getEnv`
- hardcoded absolute paths `/home/...` / `/Users/...` (→ use `config.home.homeDirectory` etc.)
- calling binaries via PATH (→ prefer a `${pkgs.foo}/bin/foo` store-path reference where possible)
- whether `flake.lock` is committed (the crux of pinning input versions)

## 2. Conventions / structure
- Where packages go: system-wide / services / root → `configuration.nix`; personal user env → `home/*.nix`
- Version channels: default is 26.05 (`pkgs.foo`), newer versions via `pkgs.unstable.foo` (flake.nix `channelsOverlay`).
  Pin a specific old version via a named input + `channelsOverlay` (no inline import of a commit hash).
- Keep modules small and single-purpose (like `home/shell.nix`, `home/git.nix`); wire them into `home/alicek106.nix`'s `imports`.
- **Simplicity**: written so a nix beginner can follow it. Avoid unnecessary abstraction/complexity.
- Put shell/lua etc. in separate files (`home/statusline.sh`, `home/nvim/*.lua`) and wrap them with nix.

## 3. Documentation duty (README.md)
- **If a non-reproducible / non-nix-like setting is genuinely required** → it MUST be documented in
  `README.md`'s "Non-declarative manual setup". Do not hide it as a stopgap inside a nix file.
- **If the instructions for rebuilding/reinstalling from scratch** (bootstrap: partition → install →
  post-install manual steps) change → keep `README.md`'s install/bootstrap section up to date.

## 4. Wrap-up
- Confirm evaluation passes with `nix flake check`. If possible, verify activation with `nixos-rebuild test`.
- When running build-type commands (`nix build`/`nixos-rebuild`), strongly tell the user "I'm building nix now".
- git commit after applying/verifying (rollback reference point).

## 5. Propose workflow improvements
If you spot repetitive manual work or inefficiency, judge whether it is worth turning into a new
skill/hook/module and proactively propose it to the user.
