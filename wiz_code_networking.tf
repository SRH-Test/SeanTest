# This is all bad stuff that one should not do

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
