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

run "defaults_do_not_publish_to_pubsub" {
  command = plan

  assert {
    condition     = length(google_pubsub_topic.this) == 0
    error_message = "No Pub/Sub topic may be created unless create_pubsub_topic is true."
  }

  assert {
    condition     = output.pubsub_topic_id == null
    error_message = "pubsub_topic_id should be null when Pub/Sub publishing is off."
  }
}

run "existing_pubsub_topic_is_published_to" {
  command = plan

  variables {
    pubsub_topic = "projects/my-project/topics/budget-events"
  }

  assert {
    condition     = length(google_pubsub_topic.this) == 0
    error_message = "An existing topic must not be created by the module."
  }

  assert {
    condition     = length(google_billing_budget.this.all_updates_rule) == 1
    error_message = "A Pub/Sub topic on its own must produce an all_updates_rule."
  }

  assert {
    condition     = google_billing_budget.this.all_updates_rule[0].pubsub_topic == "projects/my-project/topics/budget-events"
    error_message = "pubsub_topic must be passed through to all_updates_rule."
  }

  assert {
    condition     = google_billing_budget.this.all_updates_rule[0].schema_version == "1.0"
    error_message = "schema_version must be \"1.0\" whenever a Pub/Sub topic is set."
  }

  assert {
    condition     = google_billing_budget.this.all_updates_rule[0].monitoring_notification_channels == null
    error_message = "No monitoring channels were configured, so none may be set."
  }

  assert {
    condition     = google_billing_budget.this.all_updates_rule[0].disable_default_iam_recipients != true
    error_message = "Adding a Pub/Sub topic must not disable the default IAM recipients."
  }

  assert {
    condition     = output.pubsub_topic_id == "projects/my-project/topics/budget-events"
    error_message = "pubsub_topic_id should report the topic in use."
  }
}

run "pubsub_topic_and_channels_together" {
  command = plan

  variables {
    pubsub_topic = "projects/my-project/topics/budget-events"
    monitoring_notification_channels = [
      "projects/my-project/notificationChannels/1234567890",
    ]
  }

  assert {
    condition = google_billing_budget.this.all_updates_rule[0].monitoring_notification_channels == tolist([
      "projects/my-project/notificationChannels/1234567890",
    ])
    error_message = "Channels must survive alongside a Pub/Sub topic."
  }

  assert {
    condition     = google_billing_budget.this.all_updates_rule[0].pubsub_topic == "projects/my-project/topics/budget-events"
    error_message = "The Pub/Sub topic must survive alongside channels."
  }
}

run "created_pubsub_topic_is_published_to" {
  command = plan

  variables {
    pubsub_topic        = "projects/my-project/topics/budget-events"
    create_pubsub_topic = true
  }

  # Under a mock provider the computed id would otherwise be a random string;
  # pin it to the format the real provider uses.
  override_resource {
    target = google_pubsub_topic.this
    values = {
      id = "projects/my-project/topics/budget-events"
    }
  }

  assert {
    condition     = length(google_pubsub_topic.this) == 1
    error_message = "create_pubsub_topic = true must create the topic."
  }

  assert {
    condition     = google_pubsub_topic.this[0].project == "my-project" && google_pubsub_topic.this[0].name == "budget-events"
    error_message = "The created topic's project and name must be parsed from pubsub_topic."
  }

  assert {
    condition     = google_billing_budget.this.all_updates_rule[0].pubsub_topic == google_pubsub_topic.this[0].id
    error_message = "The budget must publish to the topic the module created."
  }

  assert {
    condition     = google_billing_budget.this.all_updates_rule[0].schema_version == "1.0"
    error_message = "schema_version must be \"1.0\" whenever a Pub/Sub topic is set."
  }

  assert {
    condition     = output.pubsub_topic_id == google_pubsub_topic.this[0].id
    error_message = "pubsub_topic_id should report the created topic."
  }
}

run "defaults_emit_no_budget_filter" {
  command = plan

  # Unchanged from before the filter inputs existed: no filter block, so the
  # budget covers the whole billing account with the API's credit default.
  assert {
    condition     = length(google_billing_budget.this.budget_filter) == 0
    error_message = "With no filters configured the module must omit budget_filter."
  }
}

run "service_label_and_credit_filters_are_passed_through" {
  command = plan

  variables {
    services               = ["services/6F81-5844-456A"]
    labels                 = { team = "data" }
    subaccounts            = ["billingAccounts/0123AB-4567CD-000001"]
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  assert {
    condition     = google_billing_budget.this.budget_filter[0].services == tolist(["services/6F81-5844-456A"])
    error_message = "services should be passed through to budget_filter."
  }

  assert {
    condition     = google_billing_budget.this.budget_filter[0].labels == tomap({ team = "data" })
    error_message = "labels should be passed through to budget_filter."
  }

  assert {
    condition     = google_billing_budget.this.budget_filter[0].subaccounts == tolist(["billingAccounts/0123AB-4567CD-000001"])
    error_message = "subaccounts should be passed through to budget_filter."
  }

  assert {
    condition     = google_billing_budget.this.budget_filter[0].credit_types_treatment == "EXCLUDE_ALL_CREDITS"
    error_message = "credit_types_treatment should be passed through to budget_filter."
  }

  assert {
    condition     = google_billing_budget.this.budget_filter[0].projects == null
    error_message = "Unset projects must stay null, not an empty set."
  }

  assert {
    condition     = google_billing_budget.this.budget_filter[0].credit_types == null
    error_message = "Unset credit_types must stay null, not an empty list."
  }
}

run "credit_treatment_alone_emits_a_filter" {
  command = plan

  variables {
    credit_types_treatment = "INCLUDE_SPECIFIED_CREDITS"
    credit_types           = ["COMMITTED_USAGE_DISCOUNT", "SUSTAINED_USAGE_DISCOUNT"]
  }

  assert {
    condition     = length(google_billing_budget.this.budget_filter) == 1
    error_message = "A credit treatment on its own must produce a budget_filter."
  }

  assert {
    condition = google_billing_budget.this.budget_filter[0].credit_types == tolist([
      "COMMITTED_USAGE_DISCOUNT", "SUSTAINED_USAGE_DISCOUNT",
    ])
    error_message = "credit_types should be passed through with INCLUDE_SPECIFIED_CREDITS."
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

run "rejects_bare_pubsub_topic_id" {
  command = plan

  variables {
    pubsub_topic = "budget-events"
  }

  expect_failures = [var.pubsub_topic]
}

run "rejects_create_pubsub_topic_without_a_name" {
  command = plan

  variables {
    create_pubsub_topic = true
  }

  expect_failures = [google_billing_budget.this]
}

run "rejects_bare_service_id" {
  command = plan

  variables {
    services = ["6F81-5844-456A"]
  }

  expect_failures = [var.services]
}

run "rejects_more_than_one_label" {
  command = plan

  variables {
    labels = { team = "data", env = "prod" }
  }

  expect_failures = [var.labels]
}

run "rejects_unprefixed_subaccount" {
  command = plan

  variables {
    subaccounts = ["0123AB-4567CD-000001"]
  }

  expect_failures = [var.subaccounts]
}

run "rejects_unknown_credit_types_treatment" {
  command = plan

  variables {
    credit_types_treatment = "EXCLUDE_CREDITS"
  }

  expect_failures = [var.credit_types_treatment]
}

run "rejects_credit_types_without_specified_treatment" {
  command = plan

  variables {
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
    credit_types           = ["PROMOTION"]
  }

  expect_failures = [google_billing_budget.this]
}
