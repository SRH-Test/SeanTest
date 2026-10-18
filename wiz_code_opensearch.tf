# This is all bad stuff that one should not do

# OpenSearch
resource "aws_opensearch_domain" "wiz_code" {
  domain_name    = "wiz-code-opensearch"
  engine_version = "OpenSearch_2.5"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 2
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  vpc_options {
    subnet_ids         = [aws_subnet.wiz_code1.id, aws_subnet.wiz_code2.id]
    security_group_ids = [aws_security_group.opensearch_wiz_code.id]
  }

  node_to_node_encryption {
    enabled = false
  }

  encrypt_at_rest {
    enabled = false
  }

  domain_endpoint_options {
    enforce_https = false
  }

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
