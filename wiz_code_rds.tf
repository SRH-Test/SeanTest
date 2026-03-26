# This is all bad stuff that one should not do

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
