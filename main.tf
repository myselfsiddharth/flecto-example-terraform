# A deliberately small, safe, dummy stack.
#
# Nothing here is ever applied. There are no real credentials and no backend --
# the provider is configured with mock keys and every validation skipped, so
# `terraform plan` runs offline-ish and produces a plan JSON for Flecto to read.
# That plan is the whole point of this repository.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "eu-west-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# The web tier. Reachable only from the office VPN range.
resource "aws_security_group" "web" {
  name        = "web"
  description = "Public web tier"

  ingress {
    description = "HTTPS from the office VPN"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}

# Application uploads. Public access is blocked, which is the default we want.
resource "aws_s3_bucket" "uploads" {
  bucket = "flecto-example-uploads"

  tags = {
    CostCenter = "platform"
    ManagedBy  = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The application's own role. Scoped to the one bucket it needs.
resource "aws_iam_role_policy" "app" {
  name = "app-uploads"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::flecto-example-uploads/*"
    }]
  })
}

resource "aws_iam_role" "app" {
  name = "app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
