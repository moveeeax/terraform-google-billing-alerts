variable "billing_account" {
  description = "Billing account id the budget is created under, in the bare \"XXXXXX-XXXXXX-XXXXXX\" form (no \"billingAccounts/\" prefix)."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-Za-z]{6}-[0-9A-Za-z]{6}-[0-9A-Za-z]{6}$", var.billing_account))
    error_message = "billing_account must look like \"0123AB-4567CD-89EF01\" - the bare account id, without the \"billingAccounts/\" prefix."
  }
}

variable "display_name" {
  description = "Display name of the budget."
  type        = string

  validation {
    condition     = length(trimspace(var.display_name)) > 0 && length(var.display_name) <= 60
    error_message = "display_name must be non-empty and at most 60 characters."
  }
}

variable "amount" {
  description = "Budget amount in whole units of the specified currency. Must be a positive whole number; a zero budget makes every threshold fire on any spend. Ignored when use_last_period_amount is true."
  type        = number
  default     = 100

  validation {
    condition     = var.amount > 0
    error_message = "amount must be greater than 0. A budget of 0 makes every threshold rule fire on any spend at all."
  }

  validation {
    condition     = floor(var.amount) == var.amount
    error_message = "amount must be a whole number: the Cloud Billing API takes the budget as an integer number of currency units, so fractional values are rejected at apply time."
  }
}

variable "currency_code" {
  description = "ISO 4217 currency code for the budget amount. Must match the billing account's currency."
  type        = string
  default     = "USD"

  validation {
    condition     = can(regex("^[A-Z]{3}$", var.currency_code))
    error_message = "currency_code must be a three-letter uppercase ISO 4217 code, e.g. \"USD\"."
  }
}

variable "use_last_period_amount" {
  description = "Whether to set the budget to the previous period's spend instead of a fixed amount."
  type        = bool
  default     = false
}

variable "threshold_percents" {
  description = "Threshold rules as fractions of the budget (e.g. 0.5, 0.9, 1.0) that trigger alerts. At least one is required: a budget with no threshold rules is created successfully and then never alerts anyone."
  type        = list(number)
  default     = [0.5, 0.9, 1.0]

  validation {
    condition     = length(var.threshold_percents) > 0
    error_message = "threshold_percents must contain at least one threshold. A budget with no threshold rules applies cleanly and then never alerts anyone."
  }

  validation {
    condition     = alltrue([for p in var.threshold_percents : p > 0])
    error_message = "Every entry in threshold_percents must be greater than 0. A threshold of 0 is exceeded by any spend at all, and negative thresholds are rejected by the API."
  }
}

variable "spend_basis" {
  description = "Whether threshold rules compare against CURRENT_SPEND (alert only once the money is already spent) or FORECASTED_SPEND (alert when the period is projected to exceed the threshold)."
  type        = string
  default     = "CURRENT_SPEND"

  validation {
    condition     = contains(["CURRENT_SPEND", "FORECASTED_SPEND"], var.spend_basis)
    error_message = "spend_basis must be either \"CURRENT_SPEND\" or \"FORECASTED_SPEND\"."
  }
}

variable "projects" {
  description = "Projects to scope the budget to, formatted as \"projects/<id>\". Empty applies to the whole billing account."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for p in var.projects : can(regex("^projects/[^/]+$", p))])
    error_message = "Each entry in projects must be the full resource name \"projects/<project-id-or-number>\", not a bare project id."
  }
}

variable "monitoring_notification_channels" {
  description = "Cloud Monitoring notification channels to alert, as full resource names (\"projects/<project>/notificationChannels/<id>\"). These are notified *in addition to* the billing account admins and users, who are always emailed by this module. At most 5 are allowed."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.monitoring_notification_channels) <= 5
    error_message = "The Cloud Billing API accepts at most 5 monitoring notification channels per budget."
  }

  validation {
    condition = alltrue([
      for c in var.monitoring_notification_channels :
      can(regex("^projects/[^/]+/notificationChannels/[^/]+$", c))
    ])
    error_message = "Each monitoring notification channel must be a full resource name, \"projects/<project>/notificationChannels/<id>\", not a bare channel id."
  }
}
