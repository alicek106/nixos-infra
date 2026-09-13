output "tunnel_id" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.blog.id
  description = "Tunnel UUID"
}

output "tunnel_cname" {
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  description = "apex CNAME 대상"
}

output "tunnel_token" {
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.blog.token
  description = "cloudflared tunnel run --token 토큰"
  sensitive   = true
}

output "dnssec_ds" {
  value       = cloudflare_zone_dnssec.siori.ds
  description = "레지스트라에 등록해야 하는 DS 레코드"
}
