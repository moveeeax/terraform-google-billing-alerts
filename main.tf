locals {
  # Full resource name of the topic budget notifications are published to, or
  # null when Pub/Sub publishing is off. When the module creates the topic, the
  # reference to its id also orders the topic before the budget.
  pubsub_topic = var.create_pubsub_topic ? one(google_pubsub_topic.this[*].id) : var.pubsub_topic

  # Whether to publish at all is decided from the inputs alone, so it is known
  # at plan time even while a module-created topic id is still unknown.
  pubsub_enabled = var.pubsub_topic != null

  has_budget_filter = anytrue([
    length(var.projects) > 0,
    length(var.services) > 0,
    length(var.labels) > 0,
    length(var.subaccounts) > 0,
    var.credit_types_treatment != null,
  ])
}

# Created only on request. The project and topic id are taken from
# var.pubsub_topic, so the same input names the topic whether the module
# creates it or it already exists.
resource "google_pubsub_topic" "this" {
  count = var.create_pubsub_topic && var.pubsub_topic != null ? 1 : 0

  project = regex("^projects/([^/]+)/topics/([^/]+)$", var.pubsub_topic)[0]
  name    = regex("^projects/([^/]+)/topics/([^/]+)$", var.pubsub_topic)[1]
}

resource "google_billing_budget" "this" {
  billing_account = var.billing_account
  display_name    = var.display_name

  # The API requires budget_filter, when present, to carry at least one filter
  # attribute. Emitting the block with every attribute null (the default, whole
  # billing account case) is rejected at plan time, so omit the block entirely
  # instead - that is what scopes the budget to the whole billing account.
  # Empty lists and maps are passed as null for the same reason.
  dynamic "budget_filter" {
    for_each = local.has_budget_filter ? [1] : []
    content {
      projects               = length(var.projects) > 0 ? var.projects : null
      services               = length(var.services) > 0 ? var.services : null
      labels                 = length(var.labels) > 0 ? var.labels : null
      subaccounts            = length(var.subaccounts) > 0 ? var.subaccounts : null
      credit_types_treatment = var.credit_types_treatment
      credit_types           = length(var.credit_types) > 0 ? var.credit_types : null
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

  # all_updates_rule is only emitted when there are channels or a Pub/Sub topic
  # to put in it. Omitting the block leaves the API default in place, under
  # which the billing account administrators and users are emailed.
  # disable_default_iam_recipients is deliberately never set, so that fallback
  # always survives, Pub/Sub or not.
  dynamic "all_updates_rule" {
    for_each = length(var.monitoring_notification_channels) > 0 || local.pubsub_enabled ? [1] : []
    content {
      monitoring_notification_channels = length(var.monitoring_notification_channels) > 0 ? var.monitoring_notification_channels : null
      pubsub_topic                     = local.pubsub_topic
      # "1.0" is the only schema version the API accepts.
      schema_version = local.pubsub_enabled ? "1.0" : null
    }
  }

  # Cross-variable checks, so they live here rather than in a variable
  # validation (those can only reference other variables from Terraform 1.9).
  lifecycle {
    precondition {
      condition     = !var.create_pubsub_topic || var.pubsub_topic != null
      error_message = "create_pubsub_topic = true needs pubsub_topic set to the full name of the topic to create, \"projects/<project>/topics/<topic>\"."
    }

    # The API only accepts credit_types together with INCLUDE_SPECIFIED_CREDITS.
    precondition {
      condition     = length(var.credit_types) == 0 || var.credit_types_treatment == "INCLUDE_SPECIFIED_CREDITS"
      error_message = "credit_types can only be set when credit_types_treatment is \"INCLUDE_SPECIFIED_CREDITS\"."
    }
  }
}
