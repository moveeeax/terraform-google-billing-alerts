# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-11-08

### Added

- Pub/Sub budget notifications: `pubsub_topic` publishes to a topic through
  `all_updates_rule.pubsub_topic` with `schema_version = "1.0"`, and
  `create_pubsub_topic` creates that topic in the module. New output
  `pubsub_topic_id`. Off by default, so existing budgets plan unchanged; the
  default billing-admin email recipients are still never disabled.
- Budget filters: `services`, `labels` (one key/value pair), `subaccounts`,
  `credit_types_treatment` and `credit_types` map onto `budget_filter`. All
  unset by default, so existing budgets plan unchanged. `credit_types` is
  rejected unless `credit_types_treatment = "INCLUDE_SPECIFIED_CREDITS"`.

### Changed

- CI: bump actions to their current majors, pin tool versions, and restrict the
  workflow token to `contents: read`.
- CI: add Dependabot for GitHub Actions and the Terraform provider.
- Docs: pin the README usage `source` to a release tag; fix the LICENSE year.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-google-billing-alerts/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/moveeeax/terraform-google-billing-alerts/compare/v1.1.0...v1.2.0
[1.0.0]: https://github.com/moveeeax/terraform-google-billing-alerts/releases/tag/v1.0.0
