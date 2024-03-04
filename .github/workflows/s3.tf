#s3 bucket for terraform backend
resource "aws_s3_bucket" "backend" {
  count  = var.create_vpc ? 1 : 0
  bucket = "group2-${lower(var.env)}-${random_integer.backend.result}"

  tags = {
    Name        = "My backend"
    Environment = "Dev"
  }
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "068f6659-1722-4ece-9df3-3bb119316e42"  
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

#kms key for bucket encryption
resource "aws_kms_key" "my_key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy                  = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "key-consolepolicy-3",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
          "AWS": "arn:aws:iam::657678360112:root"  
        },
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.backend[0].id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.my_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

#Random integer for bucket naming convention
resource "random_integer" "backend" {
  min = 1
  max = 100
  keepers = {
    Environment = var.env
  }
}

#versioning
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.backend[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Public access block
resource "aws_s3_bucket_public_access_block" "access_backend" {
  bucket                  = aws_s3_bucket.backend[0].id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket-config" {
  bucket = aws_s3_bucket.backend[0].id
  rule {
    id = "log"
    expiration {
      days = 90
    }
    filter {
      and {
        prefix = "log/"
        tags = {
          rule      = "log"
          autoclean = "true"
        }
      }
    }
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
  rule {
    id = "tmp"
    filter {
      prefix = "tmp/"
    }
    expiration {
      date = "2025-01-13T00:00:00Z"
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "example" {
  bucket        = aws_s3_bucket.backend[0].id
  target_bucket = aws_s3_bucket.backend[0].id
  target_prefix = "log/"
}

resource "aws_s3_bucket_lifecycle_configuration" "pass" {
  bucket = aws_s3_bucket.backend[0].id
  rule {
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    filter {}
    id     = "log"
    status = "Enabled"
  }
}
