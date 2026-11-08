output "id" {
  description = "Identifier of the budget."
  value       = google_billing_budget.this.id
}

output "name" {
  description = "Resource name of the budget."
  value       = google_billing_budget.this.name
}

output "pubsub_topic_id" {
  description = "Full resource name of the Pub/Sub topic budget notifications are published to (created by the module or passed in), or null when Pub/Sub publishing is off."
  value       = local.pubsub_topic
}
