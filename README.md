# terraform-google-billing-alerts

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
billing budget (`google_billing_budget`). It sets a spend amount (or tracks the
previous period), defines threshold rules and optionally notifies monitoring
channels.

## Usage

```hcl
module "billing_alerts" {
  source = "github.com/moveeeax/terraform-google-billing-alerts?ref=v1.0.0"

  billing_account    = "0123AB-4567CD-89EF01"
  display_name       = "prod-budget"
  amount             = 1000
  threshold_percents = [0.5, 0.8, 1.0]
  projects           = ["projects/my-app-prod"]
}
```

Omit `projects` to budget the whole billing account:

```hcl
module "billing_alerts" {
  source = "github.com/moveeeax/terraform-google-billing-alerts?ref=v1.0.0"

  billing_account = "0123AB-4567CD-89EF01"
  display_name    = "all-projects-budget"
  amount          = 5000
}
```

Alert before the money is gone rather than after, and page an on-call channel as
well as the billing admins:

```hcl
module "billing_alerts" {
  source = "github.com/moveeeax/terraform-google-billing-alerts?ref=v1.0.0"

  billing_account    = "0123AB-4567CD-89EF01"
  display_name       = "prod-forecast"
  amount             = 1000
  spend_basis        = "FORECASTED_SPEND"
  threshold_percents = [1.0]

  monitoring_notification_channels = [
    google_monitoring_notification_channel.oncall.id,
  ]
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Who actually gets notified

A budget that applies cleanly but reaches nobody is the easiest mistake to make
here, so the module is deliberately opinionated:

- **`threshold_percents` cannot be empty.** The Cloud Billing API happily
  accepts a budget with no threshold rules; it is then created successfully and
  never alerts anyone. The variable validation rejects that up front.
- **Billing account administrators and users are always emailed.** The module
  never sets `disable_default_iam_recipients`, so that fallback cannot be turned
  off. `all_updates_rule` is emitted only when there is at least one monitoring
  notification channel to put in it — an `all_updates_rule` with no channels
  would suppress nothing but is pointless, and combined with
  `disable_default_iam_recipients` it is the classic "fires at nobody" budget.
- **`monitoring_notification_channels` are additive**, not a replacement for the
  default recipients, and must be full resource names
  (`projects/<project>/notificationChannels/<id>`). Bare channel ids are
  rejected at plan time rather than at apply.
- **`spend_basis` defaults to `CURRENT_SPEND`**, which alerts only once the
  money is already spent. Use `FORECASTED_SPEND` if you want warning while the
  period is still running.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

Running the test suite (`terraform test`) additionally requires Terraform or
OpenTofu >= 1.7 for `mock_provider`. The module itself still works on 1.5.

## Inputs

| Name                               | Description                                                                                          | Type           | Default           | Required |
|------------------------------------|------------------------------------------------------------------------------------------------------|----------------|-------------------|:--------:|
| `billing_account`                  | Billing account id, bare `XXXXXX-XXXXXX-XXXXXX` form.                                                | `string`       | n/a               |   yes    |
| `display_name`                     | Display name of the budget (1-60 characters).                                                        | `string`       | n/a               |   yes    |
| `amount`                           | Budget amount in whole currency units. Must be a positive whole number.                              | `number`       | `100`             |    no    |
| `currency_code`                    | ISO 4217 currency code. Must match the billing account's currency.                                   | `string`       | `"USD"`           |    no    |
| `use_last_period_amount`           | Track previous period spend instead of a fixed amount.                                               | `bool`         | `false`           |    no    |
| `threshold_percents`               | Threshold fractions that trigger alerts. Must contain at least one entry, each greater than 0.       | `list(number)` | `[0.5, 0.9, 1.0]` |    no    |
| `spend_basis`                      | `CURRENT_SPEND` or `FORECASTED_SPEND`, applied to every threshold rule.                              | `string`       | `"CURRENT_SPEND"` |    no    |
| `projects`                         | Projects to scope the budget to, as `projects/<id>`. Empty covers the whole billing account.         | `list(string)` | `[]`              |    no    |
| `monitoring_notification_channels` | Full notification channel resource names to alert, in addition to billing admins. At most 5.         | `list(string)` | `[]`              |    no    |

## Outputs

| Name   | Description                        |
|--------|------------------------------------|
| `id`   | Identifier of the budget.         |
| `name` | Resource name of the budget.      |

## Development

```sh
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform test
tflint --recursive
```

## License

[MIT](LICENSE)
