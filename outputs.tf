output "role_arn" {
  description = "Send us this exact value."
  value       = aws_iam_role.vendor_dynamodb_access.arn
}

output "screening_table_name" {
  description = "Send us this exact value."
  value       = aws_dynamodb_table.screening.name
}

output "decision_table_name" {
  description = "Send us this exact value."
  value       = aws_dynamodb_table.decision.name
}

output "region" {
  description = "Send us this exact value."
  value       = var.region
}
