resource "google_billing_budget" "this" {
  billing_account = var.billing_account
  display_name    = var.display_name

  budget_filter {
    projects = length(var.projects) > 0 ? var.projects : null
  }

  amount {
    dynamic "specified_amount" {
      for_each = var.use_last_period_amount ? [] : [1]
      content {
        currency_code = var.currency_code
        units         = tostring(var.amount)
      }
    }

    last_period_amount = var.use_last_period_amount ? true : null
  }

  dynamic "threshold_rules" {
    for_each = var.threshold_percents
    content {
      threshold_percent = threshold_rules.value
    }
  }

  dynamic "all_updates_rule" {
    for_each = length(var.monitoring_notification_channels) > 0 ? [1] : []
    content {
      monitoring_notification_channels = var.monitoring_notification_channels
    }
  }
}
