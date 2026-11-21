let
  alice = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjDFC4ffES5BhsYNS8qNu3WTbxpvm7schvJvxUlkY9r root@nixos-alicek106"; # 서버 밀때마다 갈아줘야 함, nixos-server
  desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0D0cgXlUX8w8CFBcfYoszjLuLk4idhj4b0adxCHMS1 root@nixos-desktop";
  all = [ alice server desktop ];
in
{
  "aliced-env.age".publicKeys = all;
  "nixos-credential.age".publicKeys = all;
  "cloudflared-token.age".publicKeys = all;

  # common slack webhook
  "slack-webhook.age".publicKeys = all;

  # demo app deploy secrets
  "demo-env.age".publicKeys = all;
  "demo-deploy-key.age".publicKeys = all;
  "slack-deploy-env.age".publicKeys = all;

  ## jenkins secrets
  "ios-build-match-password.age".publicKeys = [ alice desktop ]; # match password for fastlane
  "jenkins-admin-password.age".publicKeys = [ alice desktop ]; # jenkins admin password
  "jenkins-gitea-webhook-token.age".publicKeys = [ alice desktop ]; # gitea -> jenkins push webhook token
}
