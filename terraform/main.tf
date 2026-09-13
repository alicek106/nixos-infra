resource "random_id" "tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "blog" {
  account_id    = var.cloudflare_account_id
  name          = var.tunnel_name
  tunnel_secret = random_id.tunnel_secret.b64_std
  config_src    = "cloudflare"
}

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
        // 지정된 호스트네임 외에는 404
        service = "http_status:404"
      },
    ]
  }
}

# apex(siori.dev) 레코드는 CNAME과 동시에 못쓰지만, proxied=true로 하면 CNAME flattening이 되어서 CF의 IP로 resolve가 된다.
resource "cloudflare_dns_record" "blog" {
  zone_id = var.cloudflare_zone_id
  name    = var.blog_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # proxied 일 때는 자동(1)
}

resource "cloudflare_zone_dnssec" "siori" {
  zone_id = var.cloudflare_zone_id
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "blog" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.blog.id
}
