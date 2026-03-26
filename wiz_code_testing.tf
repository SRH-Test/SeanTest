# This is all bad stuff that one should not do

# # Public S3 bucket
# resource "aws_s3_bucket" "public_bucket" {
#   bucket = "fabien-wiz-code-public-bucket"
# }

# resource "aws_s3_bucket_public_access_block" "public_bucket" {
#   bucket = aws_s3_bucket.public_bucket.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_policy" "public_bucket" {
#   bucket = aws_s3_bucket.public_bucket.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect    = "Allow"
#         Principal = "*"
#         Action    = "s3:GetObject"
#         Resource  = "${aws_s3_bucket.public_bucket.arn}/*"
#       }
#     ]
#   })
# }

# VPC
resource "aws_vpc" "wiz_code" {
  cidr_block = "10.200.0.0/16"
}

resource "aws_subnet" "wiz_code1" {
  vpc_id            = aws_vpc.wiz_code.id
  cidr_block        = cidrsubnet(aws_vpc.wiz_code.cidr_block, 8, 0)
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "wiz_code2" {
  vpc_id            = aws_vpc.wiz_code.id
  cidr_block        = cidrsubnet(aws_vpc.wiz_code.cidr_block, 8, 1)
  availability_zone = "us-east-1b"
}

resource "aws_network_acl" "wiz_code" {
  vpc_id     = aws_vpc.wiz_code.id
  subnet_ids = [aws_subnet.wiz_code1.id, aws_subnet.wiz_code2.id]

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

# RDS DB Subnet Group
resource "aws_db_subnet_group" "wiz_code" {
  subnet_ids = [aws_subnet.wiz_code1.id, aws_subnet.wiz_code2.id]
}

# Security Group for RDS
resource "aws_security_group" "rds_wiz_code" {
  vpc_id = aws_vpc.wiz_code.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "wiz_code" {
  identifier             = "wiz-code-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.wiz_code.name
  vpc_security_group_ids = [aws_security_group.rds_wiz_code.id]
  publicly_accessible    = true
  skip_final_snapshot    = true

  db_name  = "wiz_code_test_db"
  username = "admin"
  password = "admin"
}
