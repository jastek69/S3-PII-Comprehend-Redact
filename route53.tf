################################################################################
# ROUTE 53 CONFIGURATION FOR PII REDACTION API
# Custom domain: pii-api.sebekgo.com → API Gateway
################################################################################

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# ACM Certificate for API Gateway Custom Domain
# Note: For REGIONAL API Gateway, cert must be in same region
resource "aws_acm_certificate" "api_gateway" {
  domain_name       = local.api_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-api-gateway-cert"
  })
}

# DNS validation record for ACM certificate
resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_gateway.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "api_gateway" {
  certificate_arn         = aws_acm_certificate.api_gateway.arn
  validation_record_fqdns = [for record in aws_route53_record.api_cert_validation : record.fqdn]
}

# API Gateway Custom Domain
resource "aws_api_gateway_domain_name" "pii_api" {
  domain_name              = local.api_domain_name
  regional_certificate_arn = aws_acm_certificate_validation.api_gateway.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-api-custom-domain"
  })
}

# Map API Gateway to custom domain
resource "aws_api_gateway_base_path_mapping" "pii_api" {
  api_id      = aws_api_gateway_rest_api.pii_redaction_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.pii_api.domain_name
}

# Route 53 A record for custom domain
resource "aws_route53_record" "pii_api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.api_domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.pii_api.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.pii_api.regional_zone_id
    evaluate_target_health = true
  }
}
