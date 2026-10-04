# nixos-desktop VM 계획

nixos-desktop 위에서 Windows VM 두 대를 QEMU/libvirt로 운영하기 위한 결정사항 기록.

## 목적

- Windows 게임용 VM을 하나 띄운다. GTX 1660 SUPER를 패스스루해서 GPU를 쓴다.
- Windows 인터넷뱅킹 전용 VM을 하나 더 띄운다.
- 맥북(tailnet)에서 원격으로 접속한다.
- 리눅스 네트워크, 스토리지, 가상화를 직접 다뤄보며 학습한다.
  - 구현은 Claude가 가이드하고, 코드 작성과 명령 실행은 사용자가 직접 한다.

## 왜 Proxmox가 아니라 QEMU/libvirt인가

- Proxmox VE는 Debian 기반 전용 OS다. NixOS 위에 서비스로 올릴 수 없다.
  - 비공식 `proxmox-nixos`는 실험 단계라 제외했다.
- 호스트를 NixOS로 유지하면 repo의 재현성 원칙이 지켜진다.
- Proxmox가 자동으로 해주는 브리지, NAT, 스토리지 작업을 손으로 하게 되니 학습 목적에 맞는다.

## 하드웨어 현황 (2026-09-27 확인)

- CPU: Ryzen 5 2400G (4코어 8스레드). `kvm_amd`의 nested 가상화 활성.
- RAM: 15GiB
- 디스크: Samsung 850 EVO 500GB, btrfs 단일 파일시스템 (여유 약 459GB)
- GPU: GTX 1660 SUPER, IOMMU 그룹 6. 그룹 안에 다른 장치가 없다.
  - `01:00.0` `10de:21c4` VGA
  - `01:00.1` `10de:1aeb` HDMI 오디오
  - `01:00.2` `10de:1aec` USB-C xHCI
  - `01:00.3` `10de:1aed` USB-C UCSI
- 2400G의 내장 GPU는 BIOS에서 꺼져 있다 (PCI 목록에 없음).
  - GPU를 vfio로 넘기면 호스트에는 화면 출력이 없다.

## 결정사항

### 네트워크

- 방식: 내부 브리지 + 라우팅 + NAT. 물리 NIC(`enp7s0`)은 브리지에 넣지 않는다.
- 내부 대역: `10.100.0.0/24`
  - 확인한 회사 대역(`10.24.0.0/13`, `10.68.0.0/18`, `10.192.0.0/16`)과 겹치지 않는다.
  - 공유기(`192.168.0.0/16`), tailnet(`100.64.0.0/10`), 회사 노드(`172.24.x`)와도 겹치지 않는다.
- 브리지: `br-vm`, 호스트 주소 `10.100.0.1/24` (VM들의 게이트웨이)
- VM IP: 고정 할당. 호스트 DHCP 서버가 MAC 기반으로 예약 IP를 준다.
  - MAC은 IP에서 결정적으로 만든다: `52:54:00:64:00:<마지막 옥텟의 16진수>`

  | VM | IP | MAC |
  |---|---|---|
  | win-game | 10.100.0.10 | 52:54:00:64:00:0a |
  | win-bank | 10.100.0.20 | 52:54:00:64:00:14 |

- 외부 통신: nftables MASQUERADE로 `enp7s0`에 NAT
- tailnet 접속: nixos-desktop이 tailscale subnet router로 `10.100.0.0/24`를 광고한다.
  - 라우트 승인은 headscale ACL 정책 파일에 `autoApprovers`로 선언한다 (nix로 관리).
- exit node: 켜지 않는다.
- VM 간 통신: 차단한다. libvirt 인터페이스의 `<port isolated='yes'/>`(브리지 포트 격리)를 쓴다.
  - 필요하면 이 줄을 주석으로 빼서 푼다.

### GPU 패스스루

- 커널 파라미터 `vfio-pci.ids=10de:21c4,10de:1aeb,10de:1aec,10de:1aed`
- `vfio-pci`를 initrd에서 먼저 로드하고, `nouveau`를 블랙리스트에 넣는다.
- 1660S는 win-game에만 붙인다.

### VM

| | win-game | win-bank |
|---|---|---|
| 용도 | 메이플스토리 월드 | 하나은행 인터넷뱅킹 |
| vCPU / RAM | 4 / 8GiB | 2 / 4GiB |
| 디스크 | 100GB | 64GB (Windows 11 최소 요구량. sparse라 실제 사용량만 차지) |
| GPU | 1660S 패스스루 | 없음 (가상 GPU) |
| 평소 접속 | Sunshine(VM) + Moonlight(맥북) | SPICE + SSH 터널 |
| 사용 빈도 | 1~2주에 1시간 정도 | 1~2달에 한 번 |
| 자동 시작 | 안 함 | 안 함 |

- 두 VM을 동시에 켜지 않는 것을 전제로 한다.
- 펌웨어: OVMF(UEFI) + Secure Boot, swtpm(TPM 2.0). Windows 11 요구사항 때문이다.
- OS: Windows 11 Pro. 소비자용 ISO에서 Pro 에디션을 선택한다. 라이선스 없이 사용한다.
  - Enterprise는 공개 ISO가 90일 평가판뿐이라 쓰지 않는다.
- 설치 중 화면: SPICE/VNC를 호스트 localhost에만 열고, 맥북에서 SSH 터널로 접속한다.
- RDP: 쓰지 않는다.
- 드라이버: `virtio-win` ISO를 nixpkgs에서 가져온다.

### 스토리지

- VM 이미지 위치: `/var/lib/libvirt/images`, 전용 btrfs 서브볼륨
  - 디렉터리에 `chattr +C`(nodatacow)를 건다. CoW 단편화를 막기 위해서다.
  - `disk-config.nix`에 서브볼륨을 선언한다. 단 현재 머신에는 `btrfs subvolume create`를 한 번 수동으로 실행해야 한다. disko 선언은 재설치할 때만 디스크에 반영된다.
- 이미지 포맷: raw
- 할당 방식: sparse (쓴 만큼만 공간 차지)
- ISO: 사용자가 직접 받아서 둔다. 절차는 README에 있다.

### VM 정의 방식

- libvirt 도메인 XML을 repo에 넣는다 (`nixos-desktop/vms/*.xml`).
- systemd 유닛이 부팅 시 `virsh define`으로 등록한다.
- 서드파티 flake(NixVirt)는 쓰지 않는다.

### 백업

- 지금은 하지 않는다.
- 나중에 할 계획: VM 이미지 서브볼륨을 btrfs 스냅샷한 뒤 raw 이미지를 restic으로 블록 단위 백업한다.

## 알려진 위험

- **메이플스토리 월드 계정 정지 위험.** 넥슨 보안 모듈이 VM을 감지해서 실행을 막거나, 계정을 정지한 사례가 있다 (주로 본게임 사례).
- **하나은행 보안 프로그램.** VM 차단에 대한 공식 정보는 없다. 직접 테스트가 필요하다.
  - 최신 Chrome/Edge에서 "로컬 네트워크 액세스"가 차단되어 있으면 보안 프로그램이 설치되지 않는다.
- **Windows 11 설치 요구사항.**
  - 디스크가 64GB 미만이면 설치가 거부된다.
  - 2400G가 지원 CPU 목록에 없을 수 있다.
  - 막히면 설치 중 Shift+F10을 누르고 `HKLM\SYSTEM\Setup\LabConfig`에 `BypassStorageCheck`, `BypassCPUCheck`를 넣는다.
- **호스트 콘솔 상실.** vfio를 적용하면 호스트 화면이 없어진다. 네트워크 설정을 잘못하면 복구가 어렵다.
  - 변경은 항상 `nixos-rebuild test`로 먼저 적용한다.
- **자원.** RAM 15GiB라 두 VM을 동시에 켜는 것은 빠듯하다.

## 미결 사항

- [x] win-bank 디스크: 64GB
- [x] BIOS iGPU: 켜지 않는다 (호스트 복구용 콘솔 없이 운영)
- [x] Sunshine용 화면: 가상 디스플레이 드라이버 (Sunshine 파생판 Apollo에 내장). 문제가 생기면 더미 HDMI 플러그로 바꾼다.
- [ ] 메이플스토리 월드를 본 계정으로 바로 할지, 위험을 먼저 확인할지

## 진행 순서

1. 네트워크: `br-vm`, NAT, DHCP 예약, subnet router, headscale `autoApprovers`
2. 스토리지: VM 이미지 서브볼륨 생성 + nodatacow
3. libvirt 활성화 (swtpm, OVMF)
4. win-bank: GPU 없이 설치하고, 하나은행 호환성부터 확인
5. vfio 적용 후 win-game 설치, Sunshine + Moonlight 설정
