resource "google_billing_budget" "this" {
  billing_account = var.billing_account
  display_name    = var.display_name

  # The API requires budget_filter, when present, to carry at least one filter
  # attribute. Emitting the block with projects = null (the default, whole
  # billing account case) is rejected at plan time, so omit the block entirely
  # instead - that is what scopes the budget to the whole billing account.
  dynamic "budget_filter" {
    for_each = length(var.projects) > 0 ? [1] : []
    content {
      projects = var.projects
    }
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

  # threshold_rules is optional in the API: a budget with none is created
  # successfully and then never alerts anyone. var.threshold_percents is
  # validated to be non-empty so that cannot happen through this module.
  dynamic "threshold_rules" {
    for_each = var.threshold_percents
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = var.spend_basis
    }
  }

  # all_updates_rule is only emitted when there are channels to put in it.
  # Omitting the block leaves the API default in place, under which the billing
  # account administrators and users are emailed. disable_default_iam_recipients
  # is deliberately never set, so that fallback always survives.
  dynamic "all_updates_rule" {
    for_each = length(var.monitoring_notification_channels) > 0 ? [1] : []
    content {
      monitoring_notification_channels = var.monitoring_notification_channels
    }
  }
}
