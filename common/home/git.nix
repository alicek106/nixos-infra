{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "alicek106";
      user.email = "alice_k106@naver.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      url."git@github.com:".insteadOf = "https://github.com/";
      core.editor = "vim";
    };
    ignores = [ ".DS_Store" ".direnv" "result" ];
  };
}
