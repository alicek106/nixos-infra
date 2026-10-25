resource "cloudflare_zone" "demo" {
  account = {
    id = var.cloudflare_account_id
  }
  name = var.demo_zone_name
  type = "full"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_dns_record" "demo" {
  zone_id = cloudflare_zone.demo.id
  name    = var.demo_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_ruleset" "demo_geo" {
  zone_id = cloudflare_zone.demo.id
  name    = "demo geo restriction"
  kind    = "zone"
  phase   = "http_request_firewall_custom"
  rules = [
    {
      description = "Block non-KR traffic to demo"
      expression  = "(http.host eq \"${var.blog_hostname}\" and ip.src.country ne \"KR\" and not cf.client.bot)"
      action      = "block"
      enabled     = true
    },
  ]
}
