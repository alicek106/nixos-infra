terraform {
  required_version = ">= 1.10"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "alicek106-terraform-state"
    key          = "siori-blog/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "cloudflare" {}

# Uses the same AWS credentials as the S3 backend. Route53 is global; region is only required by the provider.
provider "aws" {
  region = "ap-northeast-2"
}
