# Changelog

All notable changes to Artham are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0). App version numbers and build numbers should be added to each release entry when they are confirmed.

## [Unreleased]

### Added
- Added Android automatic bank-SMS intake using the incoming SMS broadcast. Recognised new debit/credit alerts are parsed and saved to the existing local SQLite database in the background after explicit in-app consent and SMS permission.
- Added a Settings control to enable/disable automatic SMS import, with an upfront disclosure and an optional default account for messages that do not identify a specific account.
- Added account resolution using account suffix and bank/sender hints; ambiguous alerts are not assigned to an arbitrary account.
- Added local duplicate detection shared between background intake and manual SMS import. The raw SMS body is not retained.
- Retained the manual paste/share SMS import as a fallback, with editable review before saving.
- Added conservative parsing for common INR amounts, debit/credit direction, common date formats, UPI/UTR references, and basic category suggestions.
- Added opt-in rollover for unused overall and category budget balances.
- Added recurring monthly budget templates for overall and category budgets, with pause/resume controls.
- Automatically populate missing monthly budgets from active templates when opening the app or budget view; existing month budgets are never overwritten.
- Added a planned-versus-actual budget performance dashboard with overall and category-level insights.
- Added a six-month planned-versus-actual budget trend chart.
- Added month-end spending forecasts for overall and category budgets using the current month’s average daily spending pace.
- Added budget risk indicators and daily spending recommendations, with forecasts withheld until at least three elapsed days.
- Added tests for recurring templates, template backfill/effective dates, budget insights, month-end forecast calculations, and the database migration.

### Changed
- Set the user-facing app name to **Artham** across Android, iOS, and Web; kept the Dart package identifier lowercase as required.
- Upgraded the Drift database schema to version 4.
- Added the `BudgetTemplates` table while preserving existing budget records.
- Routed the Home dashboard's budget management shortcut to the full Budgets screen.
- Updated project documentation for the budget planning features.

### Added
- Added recurring transaction schedules for income and expenses.
- Added daily, weekly, monthly, and yearly recurrence frequencies.
- Added custom recurrence intervals using a scrollable number picker.
- Added start dates and optional end dates for recurring schedules.
- Added a Recurring Transactions screen accessible from the Activity screen.
- Added schedule status controls to pause and resume recurring schedules.
- Added the ability to delete a recurring schedule.
- Added due-schedule review and confirmation before creating a transaction.
- Added recurring transaction records to the normal Activity history.
- Added a recurring transaction source marker for generated entries.

### Changed
- Upgraded the Drift database schema to version 2.
- Added the `RecurringSchedules` table and its migration.
- Updated Activity with a shortcut to Recurring Transactions.
- Updated project documentation to include the recurring transactions feature.

### Fixed
- Prevented duplicate generation of the same recurring schedule occurrence.
- Preserved existing transaction records during the database schema migration.

### Verification
- `flutter analyze` completed with no issues.
- Recurring schedule creation and due-occurrence confirmation were tested in the Android emulator.
- Confirmed generated recurring transactions appear in Activity with the expected amount, category, account, description, and date.

---

## Release entry template

Copy this section for each app build or release and replace the placeholders.

```markdown
## [Version] - YYYY-MM-DD

**Build:** [Build number]

### Added
- 

### Changed
- 

### Fixed
- 

### Verification
- 
```
