# Roles assumed by the application and by the AWS services writing telemetry on
# its behalf. Every trust policy is account-conditioned; no resource wildcards.

# --- VPC flow logs -----------------------------------------------------------

data "aws_iam_policy_document" "vpc_flow_logs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    # Without this the role is assumable on behalf of any account that names it,
    # which is the confused-deputy shape AWS documents for service principals.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name_prefix        = "${var.project_name}-flow-logs-"
  description        = "Writes ${var.project_name} VPC flow logs to CloudWatch Logs."
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume.json

  tags = {
    Name = "${var.project_name}-flow-logs"
  }
}

# No logs:CreateLogGroup: the group is declared in this module, so the role only
# ever needs to write into the one that already exists.
data "aws_iam_policy_document" "vpc_flow_logs" {
  statement {
    sid    = "WriteFlowLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = ["${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name_prefix = "write-flow-logs-"
  role        = aws_iam_role.vpc_flow_logs.id
  policy      = data.aws_iam_policy_document.vpc_flow_logs.json
}

# --- RDS enhanced monitoring -------------------------------------------------

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name_prefix        = "${var.project_name}-rds-monitoring-"
  description        = "Publishes ${var.project_name} enhanced monitoring metrics."
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json

  tags = {
    Name = "${var.project_name}-rds-monitoring"
  }
}

# AWS publishes this policy for this role; a hand-written copy would drift from
# the metric set RDS emits.
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --- Application ---------------------------------------------------------------

data "aws_iam_policy_document" "application_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "application" {
  name_prefix        = "${var.project_name}-app-"
  description        = "Runtime role for the ${var.project_name} application."
  assume_role_policy = data.aws_iam_policy_document.application_assume.json

  tags = {
    Name = "${var.project_name}-app"
  }
}

data "aws_iam_policy_document" "application" {
  # Objects only. The application never needs to configure the bucket, and
  # separating these two statements is what keeps s3:* out of the policy.
  statement {
    sid    = "ReadWriteAttachmentObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.attachments.arn}/*"]
  }

  statement {
    sid       = "ListAttachmentBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.attachments.arn]
  }

  # Objects are SSE-KMS, so object access without these is a permission error at
  # runtime rather than a denied read at the bucket.
  statement {
    sid    = "UseStorageKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]

    resources = [aws_kms_key.storage.arn]
  }

  statement {
    sid       = "ReadDatabaseCredential"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.main.master_user_secret[0].secret_arn]
  }

  statement {
    sid       = "DecryptDatabaseCredential"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.database.arn]
  }

  # Scoped to one database user on one instance, which is what makes
  # iam_database_authentication_enabled usable rather than decorative.
  statement {
    sid       = "ConnectAsDatabaseUser"
    effect    = "Allow"
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.main.resource_id}/${var.database_username}"]
  }
}

resource "aws_iam_role_policy" "application" {
  name_prefix = "${var.project_name}-app-"
  role        = aws_iam_role.application.id
  policy      = data.aws_iam_policy_document.application.json
}
