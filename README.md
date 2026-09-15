# terraform-aws-dedicated-db

Sets up a dedicated database for our "dedicated database" integration:
two DynamoDB tables, plus an IAM role we can assume cross-account —
using `sts:AssumeRole` with an `ExternalId` you control — to read and
write your data, scoped to only these two tables.

This runs entirely in your own AWS account, with your own credentials.
We never receive your AWS credentials and never touch this account
directly.

## Usage

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
}

provider "aws" {
  # region here just needs to be a valid one — the module creates its
  # resources in var.region below, which can be the same or different.
  region = "eu-west-2"
}

module "dedicated_db" {
  source          = "<org>/dedicated-db/aws"
  version         = "~> 1.0"
  broker_role_arn = "<the ARN we gave you>"
  external_id     = "<the value we gave you>"
  region          = "eu-west-2" # any region you choose
}

output "role_arn"             { value = module.dedicated_db.role_arn }
output "screening_table_name" { value = module.dedicated_db.screening_table_name }
output "decision_table_name"  { value = module.dedicated_db.decision_table_name }
output "region"               { value = module.dedicated_db.region }
```

```bash
terraform init
terraform apply
```

Then send us back the four output values.

## What this creates

- Two DynamoDB tables (screening data and decision data).
- One IAM role, trusting only the broker ARN you were given, gated by
  your `external_id` — no one else can assume it.
- A policy on that role limited to read/write on just these two tables
  and their indexes. No `CreateTable`, `DeleteTable`, `UpdateTable`, or
  `DescribeTable` — schema changes always come through a new version of
  this module, never through the assumed role. Nothing else in your
  account is touched.

## Inputs

| Name | Description | Required | Default |
|---|---|---|---|
| `broker_role_arn` | The broker ARN we gave you | yes | — |
| `external_id` | The secret we agreed with you | yes | — |
| `region` | AWS region to create resources in | no | `eu-west-2` |
| `screening_table_name` | Name for the screening table | no | `dedicated-sanction-screening` |
| `decision_table_name` | Name for the decision table | no | `dedicated-sanction-decision` |
| `iam_role_name` | Name for the IAM role | no | `vendor-dynamodb-access` |

## Outputs

| Name | Description |
|---|---|
| `role_arn` | Send this back to us |
| `screening_table_name` | Send this back to us |
| `decision_table_name` | Send this back to us |
| `region` | Send this back to us |
