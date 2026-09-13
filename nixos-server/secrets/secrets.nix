let
  alice = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjDFC4ffES5BhsYNS8qNu3WTbxpvm7schvJvxUlkY9r root@nixos-alicek106"; # 서버 밀때마다 갈아줘야 함, nixos-server
  desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0D0cgXlUX8w8CFBcfYoszjLuLk4idhj4b0adxCHMS1 root@nixos-desktop";
  all = [ alice server desktop ];
in
{
  "aliced-env.age".publicKeys = all;
  "nixos-credential.age".publicKeys = all;
  "slack-webhook.age".publicKeys = all;
  "cloudflared-token.age".publicKeys = all;
}
