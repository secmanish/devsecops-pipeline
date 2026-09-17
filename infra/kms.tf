# Customer-managed encryption keys for the logging, database and storage layers,
# with the policies governing them. Each key is scoped to one layer.

# --- CloudWatch Logs ---------------------------------------------------------

# Customer-managed so the key can be audited, rotated and revoked. CloudWatch
# Logs would otherwise use an AWS-owned key.
resource "aws_kms_key" "logs" {
  description             = "${var.project_name} CloudWatch Logs encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# Separate from the key so the statements below can scope to its ARN; inlining
# the policy would make key and document reference each other.
resource "aws_kms_key_policy" "logs" {
  key_id = aws_kms_key.logs.id
  policy = data.aws_iam_policy_document.logs_kms.json
}

data "aws_iam_policy_document" "logs_kms" {
  # Without this the key becomes unmanageable: IAM alone cannot grant access to
  # a KMS key whose policy does not delegate to the account.
  statement {
    sid    = "DelegateToAccountIAM"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = [aws_kms_key.logs.arn]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]

    resources = [aws_kms_key.logs.arn]

    # Scopes the grant to log groups in this account and region, so the service
    # principal cannot be used to decrypt anything else the key protects.
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.project_name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# --- Database ----------------------------------------------------------------

resource "aws_kms_key" "database" {
  description             = "${var.project_name} database encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name = "${var.project_name}-database"
  }
}

# Declared rather than left to the AWS default, so the grant is reviewable. RDS
# reaches the key through grants it creates for the calling principal.
resource "aws_kms_key_policy" "database" {
  key_id = aws_kms_key.database.id
  policy = data.aws_iam_policy_document.database_kms.json
}

data "aws_iam_policy_document" "database_kms" {
  # Without this the key becomes unmanageable: IAM alone cannot grant access to
  # a KMS key whose policy does not delegate to the account.
  statement {
    sid    = "DelegateToAccountIAM"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = [aws_kms_key.database.arn]
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/${var.project_name}-database"
  target_key_id = aws_kms_key.database.key_id
}

# --- Object storage ----------------------------------------------------------

resource "aws_kms_key" "storage" {
  description             = "${var.project_name} object storage encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name = "${var.project_name}-storage"
  }
}

resource "aws_kms_key_policy" "storage" {
  key_id = aws_kms_key.storage.id
  policy = data.aws_iam_policy_document.storage_kms.json
}

data "aws_iam_policy_document" "storage_kms" {
  # Without this the key becomes unmanageable: IAM alone cannot grant access to
  # a KMS key whose policy does not delegate to the account.
  statement {
    sid    = "DelegateToAccountIAM"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = [aws_kms_key.storage.arn]
  }

  # Server access logging writes as a service principal, so it needs the key
  # directly. Without this the log bucket encrypts and receives nothing.
  statement {
    sid    = "AllowServerAccessLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]

    resources = [aws_kms_key.storage.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.attachments.arn]
    }
  }
}

resource "aws_kms_alias" "storage" {
  name          = "alias/${var.project_name}-storage"
  target_key_id = aws_kms_key.storage.key_id
}
