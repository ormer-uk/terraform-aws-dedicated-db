variable "broker_role_arn" {
  description = "Our broker identity's ARN — given to you by us. REQUIRED — paste the exact value shown on our platform, do not assume or reuse a prior value."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.broker_role_arn))
    error_message = "broker_role_arn must be the IAM role ARN we gave you, not left blank or guessed."
  }
}

variable "external_id" {
  description = "The one-time secret we agreed with you. REQUIRED — paste the exact value we gave you, do not make one up."
  type        = string

  validation {
    condition     = length(var.external_id) >= 8
    error_message = "external_id must be the value we sent you, not left blank or guessed."
  }
}

# Table names are entirely up to you — we don't hardcode them on our side,
# we just read back whatever you end up with from the outputs.
variable "screening_table_name" {
  description = "Name for the screening (cases) table."
  type        = string
  default     = "dedicated-sanction-screening"
}

variable "decision_table_name" {
  description = "Name for the decision (catalog) table."
  type        = string
  default     = "dedicated-sanction-decision"
}

variable "iam_role_name" {
  description = "Name for the IAM role our broker assumes into."
  type        = string
  default     = "vendor-dynamodb-access"
}
