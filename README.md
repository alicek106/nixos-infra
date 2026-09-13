# nixos-server

## 커스텀 설치 ISO

아래 명령어를 통해 iso 이미지를 빌드한다.

```bash
nix build .#nixosConfigurations.installer.config.system.build.isoImage
```

result/iso/*.iso를 USB에 dd로 넣으면 된다.

```bash
# USB Disk 번호 확인 후 진행한다.
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=result/iso/*.iso of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

참고: USB 부팅은 root로 접속해야 함

## 호스트 두 대

- `nixos-server` (`nixos-server/`) — 홈서버 본체. headscale/gitea/블로그 등 공개 서비스.
- `nixos-desktop` (`nixos-desktop/`) — 집 데스크탑(AMD Ryzen 5 2400G). 아직 서비스 없음, 기본 사용자 환경만.

두 host 모두 같은 flake(`flake.nix`)의 `nixosConfigurations.<host>`로 관리되고,
같은 home-manager 사용자 프로필(`nixos-server/home/profile.nix`)을 공유한다.
(서버는 유저 `alicek106`, 데스크탑은 유저 `desktop`으로 각각 인스턴스화됨.)

## 서버 재설치 (nixos-server)

1. `git clone https://github.com/alicek106/nixos-infra.git /tmp/nixos-infra && cd /tmp/nixos-infra`
2. 디스크 파티션 및 nixos 설치
   ```bash
   sudo nix --experimental-features "nix-command flakes" run .#disko -- \
     --mode disko ./nixos-server/disk-config.nix
   sudo nixos-install --flake .#nixos-server
   # 이후 USB 빼고 재부팅
   ```
3. agenix의 수신자를 새 host의 ssh public key로 rekey
   ```bash
   # (server) SSH 키는 ssh -A로 포워딩
   git clone https://github.com/alicek106/nixos-infra.git /home/alicek106/nixos-infra
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub

   # (mac) 자동 생성된 값을 맥북으로 가져와서 secrets.nix의 수신자로 변경한다.
   cd nixos-server/secrets # 하고 나서 secrets.nix에서 server의 pub 키로 변경한다.
   agenix -r -i ~/.ssh/<nixos-server key> # 혹은 ragenix를 사용한다.
   git commit -am "rekey secrets to new host key" && git push origin main

   # (server)
   cd /home/alicek106/nixos-infra && git pull
   sudo nixos-rebuild switch --flake .#nixos-server
   ```

4. LE 인증서를 강제로 발급한다.
   ```bash
   sudo systemctl start acme-order-renew-headscale.alicek106.com.service
   ```

---

## 수동 설정이 필요한 항목

- claude code login

## Writing

- `http://editor.alicek106.net` - `new-post "글 제목" dev` (or `essay`)
- `blog-preview` / `blog-publish`
- `/var/www/blog`: build output, `/var/lib/blog`: sources
