# This is all bad stuff that one should not do

# Public S3 bucket
resource "aws_s3_bucket" "public_bucket" {
  bucket = "fabien-wiz-code-public-bucket"
}

resource "aws_s3_bucket_public_access_block" "public_bucket" {
  bucket = aws_s3_bucket.public_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_bucket" {
  bucket = aws_s3_bucket.public_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.public_bucket.arn}/*"
      }
    ]
  })
}

# VPC
resource "aws_vpc" "wiz_code" {
  cidr_block = "10.200.0.0/16"
}

resource "aws_subnet" "wiz_code" {
  vpc_id            = aws_vpc.wiz_code.id
  cidr_block        = "10.200.0.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_network_acl" "wiz_code" {
  vpc_id     = aws_vpc.wiz_code.id
  subnet_ids = [aws_subnet.wiz_code.id]

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}
