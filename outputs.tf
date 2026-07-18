output "id" {
  description = "Identifier of the budget."
  value       = google_billing_budget.this.id
}

output "name" {
  description = "Resource name of the budget."
  value       = google_billing_budget.this.name
}
