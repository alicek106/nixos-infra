{ ... }:
{
  age.secrets = {
    aliced-env.file = ../secrets/aliced-env.age;
    # tofu output -raw tunnel_token 값에서 가져옴
    cloudflared-token.file = ../secrets/cloudflared-token.age;
    demo-env.file = ../secrets/demo-env.age;
    demo-deploy-key = {
      file = ../secrets/demo-deploy-key.age;
      owner = "demo";
    };
    slack-deploy-env.file = ../secrets/slack-deploy-env.age;
  };
}
