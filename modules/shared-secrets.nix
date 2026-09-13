{ username }:
{ ... }:
{
  age.secrets = {
    nixos-credential.file = ../secrets/nixos-credential.age;
    slack-webhook = {
      file = ../secrets/slack-webhook.age;
      owner = username;
    };
  };
}
