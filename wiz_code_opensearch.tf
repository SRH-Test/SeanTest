# This is all bad stuff that one should not do

# OpenSearch
resource "aws_opensearch_domain" "wiz_code" {
  domain_name        = "wiz-code-opensearch"
  engine_version     = "OpenSearch_2.5"
  instance_type      = "t3.small.opensearch"
  instance_count     = 2
  ebs_enabled        = true
  ebs_volume_size    = 10
  subnet_ids         = [aws_subnet.wiz_code1.id, aws_subnet.wiz_code2.id]
  security_group_ids = [aws_security_group.opensearch_wiz_code.id]
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "es:*"
        Resource  = "*"
      }
    ]
  })
  publicly_accessible_enabled     = true
  node_to_node_encryption_enabled = false
  encryption_at_rest_enabled      = false
  enforce_https                   = false
}

resource "aws_security_group" "opensearch_wiz_code" {
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
