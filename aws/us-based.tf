provider "aws" {
    region = "us-east-1"
    alias = "us-east"
}

variable "certPath" {
    type = object({
      private_key = string
      certificate_body = string
      certificate_chain = string
    })
}


resource "aws_acm_certificate" "website-domain-cert" {
    provider = aws.us-east
    private_key=file(var.certPath.private_key)
    certificate_body = file(var.certPath.certificate_body)
    certificate_chain= file(var.certPath.certificate_chain)
  }

variable "api_url" {
  type = string
}

resource "aws_apigatewayv2_domain_name" "homepage-visitorCount-api-domain" {
  provider = aws.us-east
  domain_name = var.api_url

  domain_name_configuration {
    certificate_arn = "${aws_acm_certificate.website-domain-cert.arn}"
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}
