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
