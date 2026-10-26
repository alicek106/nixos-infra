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
        hostname = var.demo_hostname
        service  = var.demo_origin_service
      },
      {
        hostname = var.demo_zone_name
        service  = var.demo_origin_service
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
  ttl     = 1
}

resource "cloudflare_zone_dnssec" "siori" {
  zone_id = var.cloudflare_zone_id
  status  = "active"
}

resource "cloudflare_ruleset" "siori_geo" {
  zone_id = var.cloudflare_zone_id
  name    = "siori geo restriction"
  kind    = "zone"
  phase   = "http_request_firewall_custom"
  rules = [
    {
      description = "Block non-KR traffic to blog (verified bots allowed)"
      expression  = "(http.host eq \"${var.blog_hostname}\" and ip.src.country ne \"KR\" and not cf.client.bot)"
      action      = "block"
      enabled     = true
    },
  ]
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "blog" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.blog.id
}
