# siori.dev 블로그를 Cloudflare Tunnel 로 노출.
#   집 IP 는 아웃바운드 터널 뒤에 숨고, Cloudflare 가 공개 HTTPS(Universal SSL) 종단.
#   ingress(무엇을 어디로) 는 여기(원격관리형)에서 관리하고, NixOS 는 토큰으로 연결만 함.

# 터널 secret (원격관리형 터널 생성에 필요)
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "blog" {
  account_id    = var.cloudflare_account_id
  name          = var.tunnel_name
  tunnel_secret = random_id.tunnel_secret.b64_std
  config_src    = "cloudflare" # ingress 를 Terraform(아래 config)이 관리
}

# Tunnel ingress: siori.dev → 로컬 nginx(블로그), 나머지는 404
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "blog" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.blog.id

  config = {
    ingress = [
      {
        hostname = var.blog_hostname
        service  = var.origin_service
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

# apex(siori.dev) → 터널. proxied=true 라야 CNAME flattening + IP 숨김.
resource "cloudflare_dns_record" "blog" {
  zone_id = var.cloudflare_zone_id
  name    = var.blog_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # proxied 일 때는 자동(1)
}

# DNSSEC 활성화 (등록처에 DS 레코드 수동 입력 필요할 수 있음 → output 참고)
resource "cloudflare_zone_dnssec" "siori" {
  zone_id = var.cloudflare_zone_id
}

# NixOS cloudflared 서비스가 쓸 터널 토큰
data "cloudflare_zero_trust_tunnel_cloudflared_token" "blog" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.blog.id
}
