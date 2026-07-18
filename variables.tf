variable "billing_account" {
  description = "Billing account id the budget is created under."
  type        = string
}

variable "display_name" {
  description = "Display name of the budget."
  type        = string
}

variable "amount" {
  description = "Budget amount in the specified currency units. Ignored when use_last_period_amount is true."
  type        = number
  default     = 100
}

variable "currency_code" {
  description = "ISO 4217 currency code for the budget amount."
  type        = string
  default     = "USD"
}

variable "use_last_period_amount" {
  description = "Whether to set the budget to the previous period's spend instead of a fixed amount."
  type        = bool
  default     = false
}

variable "threshold_percents" {
  description = "Threshold rules as fractions of the budget (e.g. 0.5, 0.9, 1.0) that trigger alerts."
  type        = list(number)
  default     = [0.5, 0.9, 1.0]
}

variable "projects" {
  description = "Projects to scope the budget to, formatted as \"projects/<id>\". Empty applies to the whole billing account."
  type        = list(string)
  default     = []
}

variable "monitoring_notification_channels" {
  description = "Monitoring notification channel ids to alert."
  type        = list(string)
  default     = []
}
