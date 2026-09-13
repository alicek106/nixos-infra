# Cloudflare Tunnel

대외 공개용 서비스를 우회 서빙하기 위한 Cloudflare Tunnel

## 준비물

- `CLOUDFLARE_API_TOKEN` (enpass 참고)
  - Account -> Cloudflare Tunnel -> Edit
  - Zone -> DNS -> Edit
  - Zone -> Zone -> Read (target DNS에 대해 설정, siori.dev 등)
- terraform.tfvars: `cloudflare_account_id`, `cloudflare_zone_id`

## 실행

```bash
export CLOUDFLARE_API_TOKEN=...

cd terraform
nix shell nixpkgs#opentofu -c tofu init
nix shell nixpkgs#opentofu -c tofu plan
nix shell nixpkgs#opentofu -c tofu apply
```

output으로 나온 터널 토큰을 agenix에 넣은 뒤 cloudflared를 실행한다.

```bash
nix shell nixpkgs#opentofu -c tofu output -raw tunnel_token

cd ../secrets
sudo EDITOR=vim agenix -e cloudflared-token.age -i /etc/ssh/ssh_host_ed25519_key
# TUNNEL_TOKEN=...
```

## 참고

인증서는 CF 터널 쓰면서 자동으로 발급된걸 쓰고 있음.

트래픽 흐름은 대충 이러하다:

```
CF edge (TLS Termination) -- Tunnel 자체 암호화 --> cloudflared -> nginx (127.0.0.1 바인딩)
```

cloudflared가 어떤 엔드포인트로 라우팅을 해야 하는지는 테라폼 레벨에서 CF에 등록하고, CF daemon은 그걸 remote config로 받아서 사용한다.
