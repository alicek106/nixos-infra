variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare Account ID (대시보드 우측 또는 zone 개요)"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "siori.dev zone ID (Cloudflare zone 개요 페이지)"
}

variable "blog_hostname" {
  type        = string
  default     = "siori.dev"
  description = "블로그 공개 호스트 (apex)"
}

variable "origin_service" {
  type        = string
  default     = "http://127.0.0.1:8080"
  description = "cloudflared 가 프록시할 로컬 nginx (블로그)"
}

variable "tunnel_name" {
  type        = string
  default     = "siori-blog"
  description = "Cloudflare Tunnel 이름"
}
