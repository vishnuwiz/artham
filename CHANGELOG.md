# Changelog

All notable changes to Artham are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0). App version numbers and build numbers should be added to each release entry when they are confirmed.

## [Unreleased]

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
