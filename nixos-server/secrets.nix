{ ... }:
{
  age.secrets = {
    aliced-env.file = ../secrets/aliced-env.age;
    # tofu output -raw tunnel_token 값에서 가져옴
    cloudflared-token.file = ../secrets/cloudflared-token.age;
    # demo 서비스: DEMO_REPO_URL=git@github.com:<org>/<repo>.git
    demo-env.file = ../secrets/demo-env.age;
    # demo 서비스: GitHub deploy key(읽기 전용) 개인키. git 이 demo 유저로 읽는다.
    demo-deploy-key = {
      file = ../secrets/demo-deploy-key.age;
      owner = "demo";
    };
  };
}
