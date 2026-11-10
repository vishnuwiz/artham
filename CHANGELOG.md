# Changelog

All notable changes to Artham are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0). App version numbers and build numbers should be added to each release entry when they are confirmed.

## [Unreleased]

### Stage 6A — Offline Merchant Recognition and Smarter Categorisation (2026-11-10)

#### Added
- Added an on-device merchant catalogue for common Indian merchants and payment descriptions across food delivery, groceries, shopping, travel, transport, utilities, entertainment, and health.
- Added whole-token alias matching with more specific aliases checked first (for example, Swiggy Instamart is recognised as Groceries rather than Swiggy Food & Dining).
- Added merchant-specific category suggestions while entering manual expense descriptions. Users can override the suggested category.
- Added persistent merchant links for recognised manual transactions, reviewed SMS imports, recurring transaction confirmations, and automatic Android SMS imports.
- Added a Merchant field to transaction details when a merchant is recognised.
- Added Dart and Kotlin tests for merchant matching, category mapping, merchant persistence, and SMS parsing.

#### Changed
- Reused the existing `Merchants` and `MoneyTransactions.merchantId` database fields; no schema migration is required.
- Limited merchant linking to expense transactions. Income transactions are not linked to expense merchants.
- Prioritised the SMS payee/counterparty over the payment-provider name, avoiding false recognition when a provider (for example, Amazon Pay) appears in an alert for an unrelated shop.
- Reset an automatically suggested category when the description changes to an unrecognised merchant, unless the user has manually selected a category.

#### Verification
- GitHub Actions validates formatting, `flutter analyze`, Flutter tests, Android release build, and native Kotlin unit tests.
- Merchant recognition is deterministic and local; unknown merchants remain unclassified rather than being guessed.
- Physical-device validation remains part of the Stage 6 acceptance checks.


### Stage 5 — Automatic Android Bank SMS Import and Account Identification (2026-11-10)

#### Added
- Added an Android SMS broadcast receiver for newly received bank and UPI debit/credit alerts. Automatic import remains opt-in and requires the Android SMS permission.
- Added account-suffix matching for masked and full account-number formats, including alerts such as `A/c XX1255`.
- Added safe account resolution: an explicit unknown or duplicate suffix is not guessed or assigned to an arbitrary account; the alert is placed in the local pending-review queue.
- Added consistent account labels using the bank name and masked last four digits across account cards, transaction details, account selectors, transfers, filters, recurring transactions, and SMS review.
- Removed the separate account-nickname input from account creation and editing. Account identification in the UI now uses the bank name and last four digits.
- Added native unit tests for account-suffix matching and Drift timestamp conversion, plus Dart tests for account display labels.

#### Changed
- Kept manual paste/share SMS import available as a fallback, with editable review before import.
- Aligned Android receiver timestamps with Drift's Unix-seconds storage convention for `DateTime` columns.
- Updated account dropdowns and transaction details to show the same masked account identifier.

#### Fixed
- Changed the Android SQLite `PRAGMA busy_timeout` call to use `rawQuery`, avoiding the SQLite exception caused by executing a row-returning pragma with `execSQL`.
- Corrected the SMS-created transaction date storage unit so imported dates display correctly instead of appearing thousands of years in the future.
- Preserved duplicate protection and ensured the original SMS body is not stored by the automatic import flow.

#### Verification
- GitHub Actions passed Dart formatting, `flutter analyze`, Flutter tests, Android release APK build, and native Kotlin unit tests for the merged Stage 5 changes.
- Validated the incoming-SMS flow in the Android emulator: a new ₹7.00 Swiggy debit alert was imported as a Food & Dining expense and assigned to the saved Federal Bank account ending in 1255.
- Confirmed the imported transaction displayed the expected date (10/11/2026) and UPI reference in the transaction details screen.
- Verified account labels in My Accounts, transaction details, Add Transaction, Transfer Money, and Settings account selectors in the Android emulator.
- Physical-device SMS permission and end-to-end validation remain pending.


### Added
- Added Android automatic bank-SMS intake using the incoming SMS broadcast. Recognised new debit/credit alerts are parsed and saved to the existing local SQLite database in the background after explicit in-app consent and SMS permission.
- Added a Settings control to enable/disable automatic SMS import, with an upfront disclosure and an optional default account for messages that do not identify a specific account.
- Added a local pending-review queue for recognised transaction alerts that cannot be safely matched to an account; users can assign an account from Settings.
- Added account resolution using account suffix and bank/sender hints; ambiguous alerts are not assigned to an arbitrary account.
- Added local duplicate detection shared between background intake and manual SMS import. The raw SMS body is not retained.
- Added app-resume refresh so transactions created by the background receiver appear in the dashboard and Activity when the app is reopened.
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
