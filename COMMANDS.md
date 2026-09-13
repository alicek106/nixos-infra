## 명령어 모음집

### nix 명령어들

```bash
nix flake check                                          # 문법 및 assertion 검증
sudo nixos-rebuild dry-activate --flake .#nixos-alicek106  # 변경 프리뷰
sudo nixos-rebuild test   --flake .#nixos-alicek106      # 재부팅 없이 임시 적용
sudo nixos-rebuild switch --flake .#nixos-alicek106      # 실제 적용, boot generation 생성
sudo nixos-rebuild switch --rollback                     # 직전 설정으로 롤백
```

### agenix

`nixos/secrets/*.age` 를 참고. 수신자는 public key + 서버 설치 시 설정된 host key이다.

```bash
cd nixos/secrets
sudo EDITOR=vim agenix -e nixos-credential.age -i /etc/ssh/ssh_host_ed25519_key
```

- **수신자(키) 변경 후 전체 재암호화**: `cd nixos/secrets && sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key`
- ⚠️ **시크릿 내용만 바꾸면 컨테이너는 자동 재시작 안 됨** — 반영하려면 아래 컨테이너 재시작 필요.
  (`.nix` 파일이 바뀌면 rebuild 가 알아서 재시작하지만, `.age` 내용 변경은 유닛 정의가 그대로라 감지 못 함)

### Podman

```bash
sudo podman ps
sudo systemctl restart podman-<service name>
sudo journalctl -u podman-<service name>
```

### Headscale

```bash
sudo headscale nodes list
sudo headscale users list
sudo headscale users create alicek106
sudo headscale preauthkeys create --user 1 --reusable --expiration 24h
sudo headscale nodes set-ip 2 100.64.0.2 # 특정 node의 IP 재고정

# 새 서버를 등록할 일이 있다면
sudo tailscale up --login-server https://headscale.alicek106.com --authkey <key> --hostname <hostname>
```

### 백업 / DDNS (타이머로 자동, 수동 실행도 가능)

```bash
systemctl list-timers

# 모종의 이유로 backup restore에 실패했다면: 아래 명령어로 재시작
sudo systemctl reset-failed <svc>-s3-restore && sudo systemctl start <svc>.service
```

### nix GC

```bash
sudo nix-collect-garbage --delete-older-than 30d
```

