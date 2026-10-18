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
