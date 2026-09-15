############################################################################
# Dedicated database — client module
#
# Called from the client's own root config, using their own AWS provider/
# credentials. Creates, in their account:
#   1. Two DynamoDB tables (screening + decision data), matching the exact
#      schema our own shared tables use.
#   2. One IAM role that trusts only our broker identity, and only when it
#      proves the external_id below — no one else can assume it.
#   3. A policy on that role scoped to just these two tables (and their
#      indexes): it can read and write data, nothing else — it cannot
#      create, delete, or describe tables, and cannot touch anything else
#      in the account.
#
# This module never configures a provider itself — the caller's root config
# supplies it, same as any other module. Resources are created in
# var.region, which can differ from the provider's own default region.
# See README.md for the few lines a client actually needs to write around
# this.
############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
}

# ── Table 1: screening (cases) ───────────────────────────────────────────
# Same PK/SK + 5 GSIs as our own dev-sanction-screening / prd-sanction-screening.
resource "aws_dynamodb_table" "screening" {
  region       = var.region
  name         = var.screening_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "company_id"
    type = "S"
  }
  attribute {
    name = "entity_createdAt"
    type = "S"
  }
  attribute {
    name = "created_by"
    type = "S"
  }
  attribute {
    name = "role_id"
    type = "S"
  }
  attribute {
    name = "assigned_to"
    type = "S"
  }

  global_secondary_index {
    name            = "entity-type-company-id-index"
    hash_key        = "company_id"
    range_key       = "entity_createdAt"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "entity-type-user-id-index"
    hash_key        = "created_by"
    range_key       = "entity_createdAt"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "sk-index"
    hash_key        = "SK"
    range_key       = "entity_createdAt"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "entity-type-role-id-index"
    hash_key        = "role_id"
    range_key       = "entity_createdAt"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "entity-type-assign-id-index"
    hash_key        = "assigned_to"
    range_key       = "entity_createdAt"
    projection_type = "ALL"
  }
}

# ── Table 2: decision (catalog) ──────────────────────────────────────────
# Same PK/SK + 1 GSI as our own dev-sanction-decision / prd-sanction-decision.
resource "aws_dynamodb_table" "decision" {
  region       = var.region
  name         = var.decision_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "group_key"
    type = "S"
  }
  attribute {
    name = "entity_createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "entity-type-group-key-index"
    hash_key        = "group_key"
    range_key       = "entity_createdAt"
    projection_type = "ALL"
  }
}

# ── IAM role our broker assumes into ─────────────────────────────────────
# Trusts exactly one principal (our broker) and requires the external_id —
# no one else, including a compromised copy of the broker's ARN alone, can
# assume this without also knowing that secret.
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.broker_role_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}

resource "aws_iam_role" "vendor_dynamodb_access" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Read/write only, on exactly these two tables and their indexes — no
# CreateTable, DeleteTable, UpdateTable, or DescribeTable. Schema changes
# always go back through this module, never through the assumed role.
data "aws_iam_policy_document" "scoped" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:TransactWriteItems",
    ]
    resources = [
      aws_dynamodb_table.screening.arn,
      "${aws_dynamodb_table.screening.arn}/index/*",
      aws_dynamodb_table.decision.arn,
      "${aws_dynamodb_table.decision.arn}/index/*",
    ]
  }
}

resource "aws_iam_role_policy" "vendor_dynamodb_access" {
  name   = "${var.iam_role_name}-dynamodb"
  role   = aws_iam_role.vendor_dynamodb_access.id
  policy = data.aws_iam_policy_document.scoped.json
}
