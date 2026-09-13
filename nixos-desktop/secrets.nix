{ ... }:
{
  age.secrets = {
    # nixos-server 와 같은 AWS 자격증명을 공유해서 쓴다 (S3 백업용).
    # 암호화된 파일 자체는 nixos-server/secrets/ 에 그대로 두고, 이 호스트 키도
    # 그 파일의 수신자 목록에 추가해서 rekey 했다 (README 참고).
    nixos-credential.file = ../nixos-server/secrets/nixos-credential.age;
  };
}
