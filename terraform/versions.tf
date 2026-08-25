terraform {
  required_version = ">= 1.10" # S3 네이티브 lockfile(use_lockfile) 사용

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # state 에 Tunnel 토큰이 들어가므로 절대 git 커밋 금지 → 암호화 S3 백엔드
  backend "s3" {
    bucket       = "alicek106-terraform-state"
    key          = "siori-blog/terraform.tfstate"
    region       = "ap-northeast-2" # TODO: 버킷 리전 확인
    encrypt      = true
    use_lockfile = true # DynamoDB 없이 S3 네이티브 락 (TF >= 1.10)
  }
}

# API 토큰은 CLOUDFLARE_API_TOKEN 환경변수로 주입 (tfvars/git 금지)
provider "cloudflare" {}
