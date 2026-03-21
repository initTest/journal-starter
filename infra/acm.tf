# 1. Look up your existing Route 53 zone
data "aws_route53_zone" "selected" {
  name         = "fake-engineer.click"
  private_zone = false
}

# 2. Request the certificate
resource "aws_acm_certificate" "api_cert" {
  domain_name       = "api.fake-engineer.click" # 👈 This is your new Subdomain!
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = local.common_tags
}

# 3. Create the Validation Record (The "Proof of Ownership")
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
}


# 4. This resource "Waits" for AWS to verify the DNS record
resource "aws_acm_certificate_validation" "api_cert" {
  certificate_arn         = aws_acm_certificate.api_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ⛳️ THE DESTINATION: Record to point your subdomain to your actual AWS Load Balancer
resource "aws_route53_record" "api_endpoint" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "api.fake-engineer.click"
  type    = "CNAME"
  ttl     = "300"

  # This "Pulls" the dynamic DNS address of the Load Balancer from your Service
  records = [kubernetes_service.journal_api.status.0.load_balancer.0.ingress.0.hostname]
}
