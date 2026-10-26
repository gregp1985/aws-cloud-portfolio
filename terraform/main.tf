
resource "aws_s3_bucket" "portfolio" {
  bucket = "gwphillips-portfolio-165030185216-eu-west-2-an"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudfront_origin_access_control" "portfolio" {
  name                              = "oac-gwphillips-portfolio-165030185216-eu-west-2-an.s-mvplmmn6gju"
  description                       = "Created by CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_cloudfront_distribution" "portfolio" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = ""
  default_root_object = "index.html"

  aliases = [
    "www.gwphillips.co.uk"
  ]

  price_class  = "PriceClass_All"
  http_version = "http2"

  tags = {
    Name = "gwphillips-portfolio"
  }

  web_acl_id = aws_wafv2_web_acl.portfolio.arn

  origin {
    domain_name = "gwphillips-portfolio-165030185216-eu-west-2-an.s3.eu-west-2.amazonaws.com"

    origin_id = "gwphillips-portfolio-165030185216-eu-west-2-an.s3.eu-west-2.amazonaws.com-mvpllcaifw4"

    origin_access_control_id = aws_cloudfront_origin_access_control.portfolio.id

    connection_attempts         = 3
    connection_timeout          = 10
    response_completion_timeout = 0

  }

  default_cache_behavior {
    target_origin_id = "gwphillips-portfolio-165030185216-eu-west-2-an.s3.eu-west-2.amazonaws.com-mvpllcaifw4"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    compress = true

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.portfolio.arn

    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled       = true
    blocked_encryption_types = ["SSE-C"]
  }
}

resource "aws_s3_bucket_policy" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  policy = jsonencode({
    Version = "2008-10-17"
    Id      = "PolicyForCloudFrontPrivateContent"

    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.portfolio.arn}/*"

        Condition = {
          ArnLike = {
            "AWS:SourceArn" = "arn:aws:cloudfront::165030185216:distribution/E376Y6O2OJ59S3"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "github_actions_deploy" {
  name                 = "GitHubActions-Portfolio-Deploy"
  path                 = "/"
  description          = ""
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = "arn:aws:iam::165030185216:oidc-provider/token.actions.githubusercontent.com"
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:gregp1985@213685089/aws-cloud-portfolio@1434817617:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "GitHubActions-Portfolio-Deploy-Policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ListPortfolioBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.portfolio.arn
      },
      {
        Sid    = "ManagePortfolioWebsiteFiles"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = "${aws_s3_bucket.portfolio.arn}/*"
      },
      {
        Sid      = "InvalidatePortfolioCloudFront"
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = "arn:aws:cloudfront::165030185216:distribution/E376Y6O2OJ59S3"
      }
    ]
  })
}

resource "aws_acm_certificate" "portfolio" {
  provider = aws.us_east_1

  domain_name       = "*.gwphillips.co.uk"
  validation_method = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_wafv2_web_acl" "portfolio" {
  provider = aws.us_east_1

  name  = "CreatedByCloudFront-52ae4b00"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "CreatedByCloudFront-52ae4b00"
  }

  lifecycle {
    prevent_destroy = true
  }
}
