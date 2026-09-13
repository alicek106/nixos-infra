# Cloudflare Tunnel

siori.dev 를 Cloudflare Tunnel 로 노출한다. 집 IP 는 아웃바운드 터널 뒤에 숨고,
Cloudflare(Universal SSL)가 공개 HTTPS 를 종단한다. 터널/DNS/ingress 는 여기(OpenTofu)에서 관리하고,
NixOS 서버(`nixos/modules/services/blog.nix`)는 토큰으로 연결만 한다.

> **실행 위치: 로컬(맥북).** 서버에는 `tofu` 를 두지 않는다. 서버는 `cloudflared` + 토큰만 있으면 된다.

## 준비물

- **OpenTofu**: `nix shell nixpkgs#opentofu -c tofu ...` (또는 `brew install opentofu`)
- **`CLOUDFLARE_API_TOKEN`** (env 로만, git/tfvars 금지). 권한:
  - Account → Cloudflare Tunnel → **Edit**  (터널은 계정 레벨)
  - Zone → DNS → **Edit**
  - Zone → Zone → **Read**  (대상: siori.dev)
  - enpass에 저장되어 있음.
- **AWS 자격증명** (state 가 S3 백엔드라 필요). 버킷 `alicek106-terraform-state` (ap-northeast-2) 접근 권한.
  - 맥북에 있는 alicek106 AWS credential 적절히 쓸 것.
- **`terraform.tfvars`** 만들기 (`terraform.tfvars.example` 복사) → `cloudflare_account_id`, `cloudflare_zone_id` 채우기.
  - 두 ID 는 Cloudflare 대시보드 → siori.dev → Overview → 우측 "API" 박스에서 복사.
  ```
  cloudflare_account_id = "50b8877060f29434c42b19cf32128e36"
  cloudflare_zone_id    = "e87faeca0a6ce7c3244fda886d13a748"
  ```

## 실행

```bash
export CLOUDFLARE_API_TOKEN=...          # 위 권한의 토큰
# AWS 자격증명도 env/profile 로 준비 (state 백엔드용)

# 혹은 opentofu 맥북에 설치했으면 그냥 해도 됨.
cd terraform
nix shell nixpkgs#opentofu -c tofu init
nix shell nixpkgs#opentofu -c tofu plan
nix shell nixpkgs#opentofu -c tofu apply
```

## apply 후: 서버에 토큰 심기 (한 번)

터널 토큰은 apply 후 output 으로 나온다. 이 토큰을 서버 agenix 에 넣어야 cloudflared 가 연결된다.

```bash
# 1) 토큰 확인
nix shell nixpkgs#opentofu -c tofu output -raw tunnel_token

# 2) 서버에서 agenix 로 저장
#    먼저 secrets/secrets.nix 수신자 목록에 아래 줄 추가:
#      "cloudflared-token.age".publicKeys = [ alice server ];
cd ../secrets
sudo EDITOR=vim agenix -e cloudflared-token.age -i /etc/ssh/ssh_host_ed25519_key
#    에디터에 한 줄:  TUNNEL_TOKEN=<위 토큰 값>

# 3) 적용
sudo nixos-rebuild switch --flake /home/alicek106/nixos-server#nixos-alicek106
```

## DNSSEC (선택)

`cloudflare_zone_dnssec` 를 켜뒀다. 등록처가 Cloudflare Registrar 가 아니면 DS 레코드를 수동 입력해야 할 수 있다:

```bash
nix shell nixpkgs#opentofu -c tofu output dnssec_ds
```

## 주의

- **state 에 터널 토큰 등 시크릿이 들어간다** → 절대 git 커밋 금지. S3 백엔드(암호화+버전+락) 사용.
- `terraform.tfvars` 는 `.gitignore` 됨. `.terraform.lock.hcl` 은 **커밋**(프로바이더 핀).
- 서버 쪽 구성은 `nixos/modules/services/blog.nix` (nginx 127.0.0.1:8080 + cloudflared 서비스).
- 검증: `curl -sI https://siori.dev/` → `HTTP/2 200` + `server: cloudflare`.
