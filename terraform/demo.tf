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

# resource "cloudflare_ruleset" "demo_geo" {
#   zone_id = cloudflare_zone.demo.id
#   name    = "demo geo restriction"
#   kind    = "zone"
#   phase   = "http_request_firewall_custom"
#   rules = [
#     {
#       description = "Block non-KR traffic to demo"
#       expression  = "(http.host eq \"${var.demo_hostname}\" and ip.src.country ne \"KR\" and not cf.client.bot)"
#       action      = "block"
#       enabled     = false
#     },
#   ]
# }

resource "cloudflare_dns_record" "demo_apex" {
  zone_id = cloudflare_zone.demo.id
  name    = var.demo_zone_name
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_ruleset" "demo_apex_redirect" {
  zone_id = cloudflare_zone.demo.id
  name    = "demo apex redirect"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"
  rules = [
    {
      description = "Redirect apex to demo host (except ads.txt)"
      # ads.txt인 경우는 바로 응답, 그 외에는 redirect
      expression = "(http.host eq \"${var.demo_zone_name}\" and http.request.uri.path ne \"/ads.txt\")"
      action     = "redirect"
      action_parameters = {
        from_value = {
          status_code           = 301
          preserve_query_string = true
          target_url = {
            expression = "concat(\"https://${var.demo_hostname}\", http.request.uri.path)"
          }
        }
      }
      enabled = true
    },
  ]
}
