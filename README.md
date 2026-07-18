# terraform-google-billing-alerts

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
billing budget (`google_billing_budget`). It sets a spend amount (or tracks the
previous period), defines threshold rules and optionally notifies monitoring
channels.

## Usage

```hcl
module "billing_alerts" {
  source = "github.com/cybercapybara/terraform-google-billing-alerts"

  billing_account    = "0123AB-4567CD-89EF01"
  display_name       = "prod-budget"
  amount             = 1000
  threshold_percents = [0.5, 0.8, 1.0]
  projects           = ["projects/my-app-prod"]
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name                               | Description                                              | Type           | Default           | Required |
|------------------------------------|----------------------------------------------------------|----------------|-------------------|:--------:|
| `billing_account`                  | Billing account id the budget is created under.          | `string`       | n/a               |   yes    |
| `display_name`                     | Display name of the budget.                              | `string`       | n/a               |   yes    |
| `amount`                           | Budget amount in currency units.                         | `number`       | `100`             |    no    |
| `currency_code`                    | ISO 4217 currency code.                                  | `string`       | `"USD"`           |    no    |
| `use_last_period_amount`           | Track previous period spend instead of a fixed amount.   | `bool`         | `false`           |    no    |
| `threshold_percents`               | Threshold fractions that trigger alerts.                 | `list(number)` | `[0.5, 0.9, 1.0]` |    no    |
| `projects`                         | Projects to scope the budget to.                         | `list(string)` | `[]`              |    no    |
| `monitoring_notification_channels` | Monitoring notification channel ids to alert.            | `list(string)` | `[]`              |    no    |

## Outputs

| Name   | Description                        |
|--------|------------------------------------|
| `id`   | Identifier of the budget.         |
| `name` | Resource name of the budget.      |

## License

[MIT](LICENSE)
