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

참고: USB 부팅은 root로 접속해야 함. installation USB에 SSH public 키 박혀있음

## unstable nixpkgs 업데이트

```bash
nix flake update nixpkgs-unstabl
sudo nixos-rebuild switch --flake .#<target>
```

## tailscale nodes

- `nixos-server` (`nixos-server/`)
- `nixos-desktop` (`nixos-desktop/`)
- m4-mackbook
- devsisters-linux (빨콩 노트북)

## 서버 재설치 (nixos-server 기준)

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

## 새 서버를 설치할 때

USB 부팅 후, disko로 디스크 포맷하고 난 뒤:

```bash
nixos-generate-config --no-filesystems --root /mnt
ls /mnt/etc/nixos/hardware-configuration.nix
```
