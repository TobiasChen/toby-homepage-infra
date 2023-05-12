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


resource "aws_acm_certificate" "website-cloudflare-domain-cert" {
    provider = aws.us-east
    private_key=file(var.certPath.private_key)
    certificate_body = file(var.certPath.certificate_body)
    certificate_chain= file(var.certPath.certificate_chain)
}

resource "aws_acm_certificate" "website-api-domain-cert" {
    private_key=file(var.certPath.private_key)
    certificate_body = file(var.certPath.certificate_body)
    certificate_chain= file(var.certPath.certificate_chain)
}


