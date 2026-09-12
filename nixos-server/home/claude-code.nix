{ pkgs, ... }:

let
  # 스크립트를 store 에 넣고, 의존성을 wrapper PATH로 bundling
  mkScriptBin = name: script: deps:
    pkgs.runCommandLocal name { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      install -Dm755 ${script} $out/bin/${name}
      wrapProgram $out/bin/${name} \
        --prefix PATH : ${pkgs.lib.makeBinPath deps}
    '';

  statusline = mkScriptBin "claude-statusline" ./statusline.sh
    (with pkgs; [ bash coreutils gnugrep gawk bc jq git ]);

  # store 경로로 생성한다.
  nixFmtHook = mkScriptBin "claude-hook-nix-fmt" ./hooks/nix-fmt.sh
    (with pkgs; [ bash coreutils jq nixpkgs-fmt ]);
  reproCheckHook = mkScriptBin "claude-hook-repro-check" ./hooks/repro-check.sh
    (with pkgs; [ bash coreutils gnugrep git ]);
  slackHook = mkScriptBin "claude-hook-slack" ./hooks/slack-notify.sh
    (with pkgs; [ bash coreutils jq curl ]);
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.unstable.claude-code;

    mcpServers = {
      nixos = {
        type = "stdio";
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
      fetch = {
        type = "stdio";
        command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";
      };
    };

    skills.nix-change-review = ./skills/nix-change-review.md;

    settings = {
      permissions = {
        defaultMode = "acceptEdits";
        allow = [
          "Bash(sudo nixos-rebuild*)"
          "Bash(nix *)"
          "Bash(nix-*)"
          "Bash(nixos-option*)"
          "Bash(sudo nix*)"
          "Bash(git *)"
          "Bash(systemctl status*)"
          "Bash(systemctl list-units*)"
          "Bash(journalctl*)"
          "Bash(ls *)"
          "Bash(find *)"
          "Bash(grep *)"
          "Bash(df *)"
          "Bash(free *)"
          "Bash(ip *)"
          "Bash(ss *)"
          "Bash(ps *)"
        ];
        deny = [
          "Read(./.env)"
          "Read(./.env.*)"
          "Read(./secrets/**)"
        ];
      };

      theme = "dark";
      model = "sonnet";
      effortLevel = "high";
      advisorModel = "sonnet";

      skipAutoPermissionPrompt = true;
      skipDangerousModePermissionPrompt = true;
      skipWorkflowUsageWarning = true;

      env = {
        DISABLE_AUTOUPDATER = "1";
        ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-5";
        CLAUDE_CODE_SUBAGENT_MODEL = "claude-sonnet-5";
        CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "50";
        ENABLE_PROMPT_CACHING_1H = "1";
        BASH_MAX_OUTPUT_LENGTH = "10000";
        MAX_MCP_OUTPUT_TOKENS = "10000";
        CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1";
        CLAUDE_CODE_DISABLE_MOUSE = "1";
      };

      statusLine = {
        type = "command";
        command = "${statusline}/bin/claude-statusline";
        padding = 0;
        refreshInterval = 10;
      };

      hooks = {
        PostToolUse = [
          {
            matcher = "Edit|Write|MultiEdit";
            hooks = [
              { type = "command"; command = "${nixFmtHook}/bin/claude-hook-nix-fmt"; }
            ];
          }
        ];
        Stop = [
          {
            hooks = [
              { type = "command"; command = "${reproCheckHook}/bin/claude-hook-repro-check"; }
            ];
          }
        ];
        Notification = [
          {
            hooks = [
              { type = "command"; command = "${slackHook}/bin/claude-hook-slack"; }
            ];
          }
        ];
      };
    };
  };
}
