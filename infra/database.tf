# Postgres instance backing the application, in the private subnets.
#
# No credential appears in this module. RDS generates the master password into
# Secrets Manager and owns its rotation, so there is nothing to place in a
# variable, a tfvars file, or state.

resource "aws_kms_key" "database" {
  description             = "${var.project_name} database encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name = "${var.project_name}-database"
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/${var.project_name}-database"
  target_key_id = aws_kms_key.database.key_id
}

resource "aws_db_subnet_group" "main" {
  name_prefix = "${var.project_name}-"
  subnet_ids  = aws_subnet.private[*].id
  description = "Private subnets for the ${var.project_name} database."

  tags = {
    Name = "${var.project_name}-database"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# rds.force_ssl rejects unencrypted connections at the server, which is the only
# place the requirement can be enforced. A client-side sslmode is a request, not
# a control.
resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.project_name}-postgres-"
  family      = "postgres${var.database_engine_version}"
  description = "Transport and connection logging settings for ${var.project_name}."

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-postgres"
  engine         = "postgres"
  engine_version = var.database_engine_version
  instance_class = var.database_instance_class

  db_name  = var.database_name
  username = var.database_username

  # Password generated, stored and rotated by RDS. Mutually exclusive with
  # `password`, which is the attribute that would otherwise put a credential in
  # state in cleartext.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.database.key_id

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.database.arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.main.name
  publicly_accessible    = false
  multi_az               = true
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  iam_database_authentication_enabled = true

  backup_retention_period  = 30
  backup_window            = "03:00-04:00"
  maintenance_window       = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-postgres-final"

  # Minor versions are applied in the maintenance window rather than deferred to
  # a code change, so a published Postgres patch does not wait on a pull request.
  auto_minor_version_upgrade = true
  apply_immediately          = false

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.database.arn
  # 7 days is the no-cost retention tier; longer windows are billed per instance.
  performance_insights_retention_period = 7

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
