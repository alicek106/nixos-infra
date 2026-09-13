{ ... }:
{
  age.secrets = {
    aliced-env.file = ../secrets/aliced-env.age;
    # tofu output -raw tunnel_token 값에서 가져옴
    cloudflared-token.file = ../secrets/cloudflared-token.age;
  };
}
