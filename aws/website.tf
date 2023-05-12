variable "url" {
    type = string
}
variable "website_name" {
  type = string
}

provider "aws" {
    region = "eu-central-1"
}

terraform {
	required_providers {
		aws = {
	    version = "~> 4.66.1"
		}
  }
}
resource "aws_s3_bucket" "homepage-bucket" {
  bucket = "${var.website_name}-default-homepage-bucket"
  object_lock_enabled = "false"
}

resource "aws_s3_bucket_public_access_block" "homepage-allow-access-block" {
  bucket = aws_s3_bucket.homepage-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_access_from_anyone-policy"{
  bucket = aws_s3_bucket.homepage-bucket.id
  policy = data.aws_iam_policy_document.allow_access_from_anyone.json

}


data "aws_iam_policy_document" "allow_access_from_anyone" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [aws_s3_bucket.homepage-bucket.arn,
      "${aws_s3_bucket.homepage-bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_website_configuration" "homepage-s3-bucket" {
  bucket = aws_s3_bucket.homepage-bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

data "aws_iam_policy_document" "github-deployment-frontend-s3-role-document" {
  statement {
    actions = ["s3:ListBucket","s3:GetObject", "s3:PutObject"]
    resources = [aws_s3_bucket.homepage-bucket.arn,"${aws_s3_bucket.homepage-bucket.arn}/*"]
    
  }
}


data "aws_iam_policy_document" "github-deployment-frontend-cloudefront-role-document" {
  statement {
    actions = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.homepage-cloudefront.arn]
    
  }
}

data "aws_iam_policy_document" "github-deployment-fronted-assume-role" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::221675488713:oidc-provider/token.actions.githubusercontent.com"]
    }

    condition {
      test = "StringLike"
      variable =  "token.actions.githubusercontent.com:sub"
      values = [ "repo:TobiasChen/toby-homepage:*"]
    }

    condition {
      test = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values = ["sts.amazonaws.com"]
    }

  }
}

resource "aws_iam_role" "github-deployment-frontend-role" {
  name               = "github-deployment-frontend-role"
  assume_role_policy = data.aws_iam_policy_document.github-deployment-fronted-assume-role.json
}

resource "aws_iam_policy" "github-deployment-frontend-s3-role-policy" {
    name        = "github-deployment-frontend-s3-role-policy"
    path        = "/"
    policy      = data.aws_iam_policy_document.github-deployment-frontend-s3-role-document.json
}

resource "aws_iam_policy" "github-deployment-frontend-cloudefront-role-policy" {
    name        = "github-deployment-frontend-cloudefront-role-policy"
    path        = "/"
    policy      = data.aws_iam_policy_document.github-deployment-frontend-cloudefront-role-document.json
}

resource "aws_iam_role_policy_attachment" "github-deployment-frontend-s3-attach_policy" {
  role       = "${aws_iam_role.github-deployment-frontend-role.name}"
  policy_arn = aws_iam_policy.github-deployment-frontend-s3-role-policy.arn
}

resource "aws_iam_role_policy_attachment" "github-deployment-frontend-cloudefront-attach_policy" {
  role       = "${aws_iam_role.github-deployment-frontend-role.name}"
  policy_arn = aws_iam_policy.github-deployment-frontend-cloudefront-role-policy.arn
}



resource "aws_cloudfront_distribution" "homepage-cloudefront" {
  aliases = [var.url]

  default_cache_behavior {
    allowed_methods        =  ["HEAD", "GET"]
    cached_methods         =  ["HEAD", "GET"]
    target_origin_id       = "${aws_s3_bucket_website_configuration.homepage-s3-bucket.website_endpoint}"
    compress               = "true"
    default_ttl            = "0"
    max_ttl                = "0"
    min_ttl                = "0"
    smooth_streaming       = "false"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  enabled         = "true"
  http_version    = "http2"
  is_ipv6_enabled = "true"

  origin {
    connection_attempts = "3"
    connection_timeout  = "10"

    custom_origin_config {
      http_port                = "80"
      https_port               = "443"
      origin_keepalive_timeout = "5"
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = "30"
      origin_ssl_protocols     = ["TLSv1.2"]
    }

    domain_name = "${aws_s3_bucket_website_configuration.homepage-s3-bucket.website_endpoint}"
    origin_id   = "${aws_s3_bucket_website_configuration.homepage-s3-bucket.website_endpoint}"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  retain_on_delete = "false"

  viewer_certificate {
    acm_certificate_arn            = "${aws_acm_certificate.website-cloudflare-domain-cert.arn}"
    cloudfront_default_certificate = "false"
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }
}



output "cloudefront_url" {
  value = aws_cloudfront_distribution.homepage-cloudefront.domain_name
}