# Test-only requirement: mock_provider needs Terraform >= 1.7 (OpenTofu >= 1.7).
# The module itself still supports >= 1.5 - do not raise required_version in
# versions.tf just to run these tests.

mock_provider "google" {}

variables {
  billing_account = "0123AB-4567CD-89EF01"
  display_name    = "test-budget"
}

run "defaults_alert_someone" {
  command = plan

  assert {
    condition     = length(google_billing_budget.this.threshold_rules) == 3
    error_message = "The default budget must have threshold rules; a budget with none never alerts."
  }

  assert {
    condition = tolist([
      for r in google_billing_budget.this.threshold_rules : r.threshold_percent
    ]) == tolist([0.5, 0.9, 1.0])
    error_message = "Default thresholds should be 50%, 90% and 100% of the budget."
  }

  assert {
    condition = alltrue([
      for r in google_billing_budget.this.threshold_rules : r.spend_basis == "CURRENT_SPEND"
    ])
    error_message = "Threshold rules should default to CURRENT_SPEND."
  }

  # No monitoring channels configured, so all_updates_rule must be absent.
  # That is what leaves the API default in place, under which billing account
  # admins and users are emailed. Emitting an empty rule instead would produce a
  # budget that fires and reaches nobody.
  assert {
    condition     = length(google_billing_budget.this.all_updates_rule) == 0
    error_message = "With no notification channels the module must omit all_updates_rule so the default billing-admin recipients still get the alert."
  }

  assert {
    condition     = google_billing_budget.this.amount[0].specified_amount[0].units == "100"
    error_message = "Default budget amount should be 100 whole currency units."
  }

  assert {
    condition     = google_billing_budget.this.amount[0].specified_amount[0].currency_code == "USD"
    error_message = "Default currency should be USD."
  }
}

run "channels_are_added_without_dropping_default_recipients" {
  command = plan

  variables {
    monitoring_notification_channels = [
      "projects/my-project/notificationChannels/1234567890",
    ]
  }

  assert {
    condition     = length(google_billing_budget.this.all_updates_rule) == 1
    error_message = "Configured notification channels must produce an all_updates_rule."
  }

  assert {
    condition = google_billing_budget.this.all_updates_rule[0].monitoring_notification_channels == tolist([
      "projects/my-project/notificationChannels/1234567890",
    ])
    error_message = "The configured channel must be passed through to all_updates_rule."
  }

  assert {
    condition     = google_billing_budget.this.all_updates_rule[0].disable_default_iam_recipients != true
    error_message = "The module must never disable the default IAM recipients; that combination silently removes the last fallback."
  }
}

run "forecasted_spend_basis_is_applied_to_every_rule" {
  command = plan

  variables {
    spend_basis        = "FORECASTED_SPEND"
    threshold_percents = [0.9, 1.0]
  }

  assert {
    condition = alltrue([
      for r in google_billing_budget.this.threshold_rules : r.spend_basis == "FORECASTED_SPEND"
    ])
    error_message = "spend_basis must be applied to every threshold rule."
  }
}

run "last_period_amount_replaces_specified_amount" {
  command = plan

  variables {
    use_last_period_amount = true
  }

  assert {
    condition     = google_billing_budget.this.amount[0].last_period_amount == true
    error_message = "use_last_period_amount should set last_period_amount."
  }

  assert {
    condition     = length(google_billing_budget.this.amount[0].specified_amount) == 0
    error_message = "specified_amount must not be set alongside last_period_amount."
  }
}

run "projects_scope_is_passed_through" {
  command = plan

  variables {
    projects = ["projects/my-app-prod"]
  }

  assert {
    condition     = google_billing_budget.this.budget_filter[0].projects == toset(["projects/my-app-prod"])
    error_message = "projects should be passed through to budget_filter."
  }
}

# --- Input guards ------------------------------------------------------------

run "rejects_empty_threshold_percents" {
  command = plan

  variables {
    threshold_percents = []
  }

  expect_failures = [var.threshold_percents]
}

run "rejects_non_positive_threshold_percent" {
  command = plan

  variables {
    threshold_percents = [0, 0.9]
  }

  expect_failures = [var.threshold_percents]
}

run "rejects_zero_amount" {
  command = plan

  variables {
    amount = 0
  }

  expect_failures = [var.amount]
}

run "rejects_fractional_amount" {
  command = plan

  variables {
    amount = 100.5
  }

  expect_failures = [var.amount]
}

run "rejects_unknown_spend_basis" {
  command = plan

  variables {
    spend_basis = "PROJECTED_SPEND"
  }

  expect_failures = [var.spend_basis]
}

run "rejects_bare_notification_channel_id" {
  command = plan

  variables {
    monitoring_notification_channels = ["1234567890"]
  }

  expect_failures = [var.monitoring_notification_channels]
}

run "rejects_more_than_five_notification_channels" {
  command = plan

  variables {
    monitoring_notification_channels = [
      "projects/p/notificationChannels/1",
      "projects/p/notificationChannels/2",
      "projects/p/notificationChannels/3",
      "projects/p/notificationChannels/4",
      "projects/p/notificationChannels/5",
      "projects/p/notificationChannels/6",
    ]
  }

  expect_failures = [var.monitoring_notification_channels]
}

run "rejects_bare_project_id" {
  command = plan

  variables {
    projects = ["my-app-prod"]
  }

  expect_failures = [var.projects]
}

run "rejects_prefixed_billing_account" {
  command = plan

  variables {
    billing_account = "billingAccounts/0123AB-4567CD-89EF01"
  }

  expect_failures = [var.billing_account]
}

run "rejects_empty_display_name" {
  command = plan

  variables {
    display_name = "   "
  }

  expect_failures = [var.display_name]
}
