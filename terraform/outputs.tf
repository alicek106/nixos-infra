output "tunnel_id" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.blog.id
  description = "Tunnel UUID"
}

output "tunnel_cname" {
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.blog.id}.cfargotunnel.com"
  description = "apex CNAME 대상"
}

# NixOS agenix 에 넣을 토큰. 다음으로 꺼낸다:
#   terraform output -raw tunnel_token
output "tunnel_token" {
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.blog.token
  description = "cloudflared tunnel run --token 용 토큰 (agenix 에 저장)"
  sensitive   = true
}

# DNSSEC DS 레코드 (등록처에 입력해야 할 수 있음)
output "dnssec_ds" {
  value       = cloudflare_zone_dnssec.siori.ds
  description = "등록처에 등록할 DS 레코드"
}
