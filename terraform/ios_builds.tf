data "aws_route53_zone" "alicek106_com" {
  name = "alicek106.com"
}

resource "aws_route53_record" "builds" {
  zone_id = data.aws_route53_zone.alicek106_com.zone_id
  name    = "builds.alicek106.com"
  type    = "A"
  ttl     = 300
  records = ["100.64.0.2"]
}
