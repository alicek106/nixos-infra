{ ... }:
{
  age.secrets = {
    nixos-credential.file = ./secrets/nixos-credential.age;
    aliced-env.file = ./secrets/aliced-env.age;
    slack-webhook = {
      file = ./secrets/slack-webhook.age;
      owner = "alicek106";
    };
    # cloudflared tunnel 토큰. tofu output -raw tunnel_token 으로 채운다.
    cloudflared-token.file = ./secrets/cloudflared-token.age;
  };
}
