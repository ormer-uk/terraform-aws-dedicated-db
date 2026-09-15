> **INTERNAL ONLY — do not copy this file to the public repo.**
> It references our real test account ID and internal reasoning that must
> never go into public git history. The public repo's README is
> `PUBLIC_README.md` in this same folder — copy *that* one instead.

# Dedicated database — client module

A real Terraform module (`variables.tf` / `main.tf` / `outputs.tf`), meant
to be referenced with a `module` block from the client's own root config —
not copy-pasted. They write ~10 lines; this module does everything else.

## What the client actually writes

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"   # whichever region they want their tables in
}

module "dedicated_db" {
  source          = "<org>/dedicated-db/aws"   # exact value depends on the new org's name — see below
  version         = "~> 1.0"
  broker_role_arn = "<the ARN shown on our platform>"
  external_id     = "<the value we gave them>"
  # table/role names have sensible defaults; override only if needed:
  # screening_table_name = "..."
  # decision_table_name  = "..."
  # iam_role_name        = "..."
}

output "role_arn"             { value = module.dedicated_db.role_arn }
output "screening_table_name" { value = module.dedicated_db.screening_table_name }
output "decision_table_name"  { value = module.dedicated_db.decision_table_name }
output "region"                { value = module.dedicated_db.region }
```

Then: `terraform init && terraform apply`, and send us back those four
outputs.

## Where this lives — decided: public Terraform Registry

New GitHub org, new public repo, published to registry.terraform.io.
Reasoning and the alternatives considered are in the project's chat
history — short version: nothing in this module is secret (`external_id`
and `broker_role_arn` are both required, no defaults), so public costs
nothing and avoids having to mint/rotate/revoke an access credential per
client forever, which a private repo would require.

### New repo structure

The registry expects the module's `.tf` files at the repo **root**, not
nested — unlike here in `screening-infra` where this folder is nested
under `terraform/client-templates/dedicated-db/` for staging purposes.
When the new repo is created:

```
terraform-aws-dedicated-db/          ← repo name is NOT flexible, see below
├── main.tf
├── variables.tf
├── outputs.tf
├── README.md
└── .github/
    └── workflows/
        ├── validate.yml            ← from ci/validate.yml here
        └── release.yml             ← from ci/release.yml here
```

**The repo name is load-bearing**: the registry auto-discovers modules
named exactly `terraform-<PROVIDER>-<NAME>` — here that's
`terraform-aws-dedicated-db`. Get this wrong and the registry won't find
it. Once published, clients reference it as `<org>/dedicated-db/aws`.

### One-time manual step (can't be scripted)

After the repo exists and has at least one `vX.Y.Z` tag:
1. Sign in to [registry.terraform.io](https://registry.terraform.io) with
   the new GitHub org's account (OAuth) — this is the step nothing above
   automates, it requires a human clicking through GitHub's OAuth consent.
2. "Publish" → "Module" → select the repo.
3. Done — the registry now watches that repo for new tags automatically.

### Ongoing releases

`ci/release.yml` (→ `.github/workflows/release.yml`) is a manual
`workflow_dispatch`: give it a version number, it re-runs `fmt`/`validate`,
tags, pushes, and cuts a GitHub Release. The registry picks up the new
tag within a few minutes on its own — no further action, no re-triggering
anything on registry.terraform.io itself.

## What we do with what they send back

The four outputs map directly onto `dedicated_db_routing.py`'s expected
fields on the company's `dev-sanction-companies` record:
`dedicated_db_role_arn`, `dedicated_db_screening_table_name`,
`dedicated_db_decision_table_name`, `dedicated_db_region` (plus
`dedicated_db_external_id`, which we already have — we generated it).
`review_dedicated_db_request` writes those onto the company with
`system_type = "dedicated"`; `claim_case` then routes that company's
reads/writes to their table instead of the shared one.

## Testing this yourself against `dev-dedicated-client-test` (773138022855)

Write the same tiny wrapper above, but with `source = "../"` (a relative
path works fine for local testing — no hosting needed yet). Set
`broker_role_arn = "arn:aws:iam::603366204987:role/dev-dedicated-db-broker"`
(the real dev broker) and pick any `external_id` (≥8 chars), then
`terraform apply` with credentials for `773138022855`. Use that same
`external_id` when registering this test company via `request_dedicated_db`
/ `review_dedicated_db_request`, so both sides agree on it.

## Why the IAM policy looks the way it does

Read/write only — `GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`,
`Query`, `BatchGetItem`, `BatchWriteItem`, `TransactWriteItems` (the last
one specifically because `claim_case` uses it). No `CreateTable`,
`DeleteTable`, `UpdateTable`, or `DescribeTable` — schema changes always
go back through this module, never through the assumed role. Resources
are scoped to exactly these two tables and their indexes, never `"*"`.
