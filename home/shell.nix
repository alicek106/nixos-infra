{ config, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 90000;
      save = 90000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
    };

    shellAliases = {
      gst = "git status";
      gs = "git switch";
      gp = "git pull origin";
    };

    # 직접적으로 지원되지 않는 옵션들만 여기에 강제로 넣는다.
    initContent = ''
      # emacs 키맵 강제 (EDITOR=nvim 때문에 zsh 가 vi 모드를 자동선택 → Ctrl+A/E 등이 깨짐).
      # 반드시 다른 bindkey 보다 먼저.
      bindkey -e

      # Ctrl+S (터미널 freeze) 끄기
      stty stop undef

      # zsh globbing 오류 무시
      setopt +o nomatch

      # Alt + ←/→ 로 단어 단위 이동
      bindkey "^[^[[C" forward-word
      bindkey "^[^[[D" backward-word
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      format = ''
        $kubernetes $directory $git_branch$git_status$aws
        $character
      '';

      right_format = "$time";

      git_branch = {
        format = "[$branch]($style) ";
      };

      git_status = {
        format = "([$ahead_behind$all_status]($style)) ";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        modified = "*";
        staged = "+";
        untracked = "?";
        deleted = "x";
        style = "red bold";
      };

      kubernetes = {
        disabled = false;
        symbol = "☸️ ";
        format = "[$symbol$context( \\($namespace\\))]($style) ";
      };

      directory = {
        style = "cyan";
        truncate_to_repo = false;
        truncation_length = 0;
        format = "[$path]($style) ";
      };

      aws = {
        style = "yellow";
        format = ''\[☁️ [$profile]($style)\] '';
      };

      time = {
        disabled = false;
        format = "[$time]($style) ";
        time_format = "%r";
        style = "bold green";
      };

      cmd_duration = {
        min_time = 500;
        format = "took [$duration]($style) ";
        style = "bold red";
        show_milliseconds = true;
      };
    };
  };

  programs.fzf.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
