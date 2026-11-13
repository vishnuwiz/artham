# Changelog

All notable changes to Artham are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0). App version numbers and build numbers should be added to each release entry when they are confirmed.

## [Unreleased]

### More micro-interactions (2026-11-13)

#### Added
- Activity: the All / Income / Expenses filter is now a single segmented control whose highlight glides, with a small overshoot, to the chosen option. Changing the filter replays the staggered row entrance.
- Add transaction and transfers: saving shows a confirmation where a mint circle pops in, a tick draws itself and a ring pulses outward, then the screen closes.
- Insights: the savings card has a ring that sweeps to your savings rate, counts the percentage up and glows once as it lands.

All effects are skipped when the system "reduce motion" setting is on.

### Micro-interactions (2026-11-13)

#### Added
- Home account cards and Budgets category cards shrink slightly while pressed and spring back; Home account cards also open Accounts on tap.
- Shimmering skeleton placeholders replace the loading spinners on Home accounts, Insights and Budgets.
- Budget bars glow once when they reach 80% of their limit, and also shake briefly when over it (Home, Budgets and Insights).
- Insights bar charts: tap a month to highlight it, dim the others and see its exact amounts; tap again to clear.
- The selected tab icon pops slightly as the tab capsule slides in.

All effects are skipped when the system "reduce motion" setting is on.

_No unreleased changes yet._

## [0.1.0] - 2026-11-13

**GitHub release tag:** `v0.1.0`  
**Platform:** Android beta APK · [Download APK](https://github.com/vishnuwiz/artham/releases/download/v0.1.0/app-release.apk) · [GitHub release page](https://github.com/vishnuwiz/artham/releases/tag/v0.1.0)

This is the first public Android beta of Artham. It brings together the local-first finance tracker, transaction and account management, budget planning, recurring transactions, offline merchant recognition, user-initiated SMS import, and local CSV/JSON export.

### Added
- Published the Android beta APK as `app-release.apk` on GitHub Releases.
- Animated spending-by-category and budget-split donut charts, with animated balance, income, expense and progress values.
- Salary as a dedicated built-in Income category, while retaining the general Income category for other credits.

### Changed
- Made the Settings export area more compact, with the export actions initially collapsed and concise CSV/JSON share and save controls.
- Matched Home's own-account transfer styling to the lavender transfer treatment used in Activity.
- Connected Home's Recent Transactions **See all** action to the Activity screen.
- Kept internal transfers as their own transaction type rather than Income or Expense categories.

### Fixed
- Fixed the Home Recent Transactions **See all** control, which previously did not navigate.
- Corrected the Home transfer amount and icon colours so transfers are not styled as expenses.

### Verification
- `flutter analyze` completed with no issues.
- `flutter test` passed all 139 tests.
- The Android release APK was built and uploaded to the GitHub release linked above.

### Animated charts and balances (2026-11-13)

#### Added
- Insights > Where your money goes: an animated donut (pie) chart of this month's spending by category. The ring sweeps open, and tapping a slice pops it out and shows its amount and share in the centre. Smaller categories are grouped as "Other".
- Budgets > Budget split: an animated donut chart of how the available budget is divided between categories.
- Home: the total balance, monthly income and expenses, account balances and the monthly budget amount count up when they appear, glide to new values when they change, and fade when the balance is hidden or shown.

#### Changed
- Every progress bar and bar chart on Home, Insights and Budgets now animates from zero with an eased, staggered fill, and percentages count up alongside. Animations are skipped when the system "reduce motion" setting is on.

### Transaction date and time (2026-11-12)

#### Added
- Added a transaction time picker below Transaction Date when creating or editing income, expense and internal transfer records.
- Displayed the saved transaction time alongside the date in transaction details, using a 12-hour AM/PM format.

#### Changed
- Changing the transaction date preserves the selected hours and minutes; selecting a time updates the existing transaction timestamp.

#### Data compatibility
- Reused the existing `transactionDate` DateTime field. No database schema migration is required, and existing transaction records remain compatible.

#### Verification
- `flutter analyze` completed with no issues.
- `flutter test` passed all 126 tests.
- The release APK built successfully and the updated app was installed and tested on an Android phone.

### Custom categories (2026-11-12)

#### Added
- Settings > Categories: add your own expense and income categories with a name, a Material icon and a colour, and edit or remove existing ones.
- Added Salary as a built-in Income category while retaining the general Income category for other credits.
- Category icons in the Add Transaction, transaction edit, recurring schedule and SMS import pickers.
- SMS import suggests the new categories, including ATM, Card Repayment, Loan, Electricity, Internet & Telecom, Insurance and Reimbursement.

#### Changed
- Database schema version 5 adds `seed_key` and `is_archived` to `categories`. Built-in categories from earlier versions are renamed in place (for example Food & Dining → Restaurants, Groceries → Food & Grocery, Salary → Income), so existing transactions, budgets and schedules keep their category. Interest is kept as it is.
- A category that transactions, budgets, schedules or merchants still use is hidden rather than deleted, and can be restored. Built-in categories are always hidden rather than deleted, so they are not re-created.
- Self Transfer is not an Income or Expense category; moving money between the user's own accounts uses the dedicated transfer transaction type.
- The merchant catalogue now uses the new names. Bills & Utilities merchants are split into Electricity, Internet & Telecom and Utility, and Health merchants into Medical, Fitness and Insurance.
- Default categories are created at app start rather than when Add Transaction is first opened.
- JSON backups include each category's seed key and hidden state.

### Beta branding and animated splash (2026-11-11)

#### Changed
- Added the beta Artham launcher artwork for Android and iOS, including adaptive Android icon layers.
- Replaced the prior startup intro with the animated pastel A and rupee coin splash, BETA ribbon, Malayalam wordmark, and tagline.
- Configured matching lavender native launch screens.


### Stage 8 — Remove Automatic Android SMS Intake (2026-11-11)

#### Changed
- Removed the Android incoming-SMS broadcast receiver, `RECEIVE_SMS` permission declaration, and native SMS permission/settings channel.
- Removed automatic SMS enable/disable controls, default-account matching preferences, and the pending automatic-import review UI.
- Kept manual SMS paste/share import in Activity, including editable transaction review, local duplicate detection, and merchant/category recognition.

#### Privacy and data preservation
- Artham no longer monitors incoming messages or requests SMS permissions.
- Existing `ProcessedSms` fingerprints remain in the local database so older imports and duplicate protection are preserved.
- No database migration or transaction deletion is required. Legacy pending-review rows from older installations are left untouched and remain included in JSON backups when present.

#### Verification
- Android manifest permission/receiver audit, Flutter analysis, unit/widget tests, and debug APK build are required before merging.
- Confirm on a device that Activity > Import SMS still parses and imports a user-selected message.


### Stage 7 — Local Data Export (2026-11-11)

#### Added
- Added a transaction CSV export with account, transfer destination, category, merchant, reference, notes, source, date, and amount fields.
- Added a structured JSON backup containing all Drift tables and the Android pending-SMS review queue when available.
- Added native Android/iOS sharing so users can save or share generated exports from Settings.
- Added separate native Save As actions for CSV and JSON so users can select a device folder such as Downloads instead of relying on the Android share sheet.
- Added CSV formula-injection protection for untrusted text fields and UTF-8 BOM support for spreadsheet compatibility.

#### Safety and data
- Export generation runs locally and does not upload financial data to a server.
- The JSON backup is unencrypted and the Settings screen warns users to store it securely.
- No database schema change or transaction mutation is required. Restore/import is not part of this stage.

#### Verification
- Added unit tests for empty and populated CSV exports and the JSON backup structure. Local execution is pending dependency installation and test commands.


### Dark glass redesign (2026-11-10)

#### Changed
- Replaced the light green theme with a dark purple "glass" look across every screen: translucent cards and inputs tinted with the logo's lavender, mint and peach over a glowing purple ground.
- Added `lib/theme/artham_theme.dart` as the single source for colours, the Material theme, the screen background and the glass tab bar; screens no longer define their own palette values.
- Replaced the Material navigation bar with a floating glass tab bar. Unselected tabs are white; the selected tab is a white capsule with dark icon and label.
- Debit amounts and over-budget states are shown in red; income is shown in mint.
- The dashboard header shows the Artham logo.

#### Safety and data
- Presentation only: no schema, repository, SMS import or balance logic changed.

### Stage 6C — Merchant-Level Spending Insights (2026-11-10)

#### Added
- Added a current-month ranking of recognised merchants by total spend, with category and transaction-count context.
- Added local unusual-spend indicators comparing month-to-date merchant spending with the average through the same calendar day in the previous three completed months.
- Require at least three distinct historical payment dates across two or more months, a rise greater than 50%, and at least ₹500 above the historical same-date average before flagging unusual spend.

#### Safety and data
- Analytics use existing local merchant and transaction records; transfers, future-dated entries, unrecognised merchants, and nonpositive amounts are excluded.
- The analysis is read-only and does not alter transactions, recurring schedules, account balances, or the database schema.

#### Verification
- Add unit coverage for merchant ranking, unusual-spend thresholds, minimum history, future-dated entries, and result limits.
- Extend the Insights widget test to verify merchant rankings and an unusual-spend indicator.


### Pastel branding refresh
- Use the supplied pastel Artham mark for Android and iOS launcher icons.
- Add a short animated Flutter startup splash with the pastel A mark, rupee coin, Malayalam wordmark, and tagline.
- Change the native Android/iOS launch screen to a soft lavender background so it transitions into the animated splash.


### Stage 6B — Recurring Payment Pattern Detection (2026-11-10)

#### Added
- Added conservative on-device detection of likely recurring income and expense patterns from transaction history.
- Require at least three distinct transaction dates, a stable weekly/monthly cadence (including multi-month and yearly intervals), and amounts within a tolerance before suggesting a pattern.
- Group candidate transactions by bank account, transaction type, category, and recognised merchant or normalised description.
- Ignore transfers, future-dated entries, generated recurring transactions, and patterns already covered by an existing schedule.
- Show detected patterns in Recurring Transactions with the observed amount, account, category, occurrence count, last payment, and next expected date.
- Prefill the existing schedule form so the user can review and edit all details before explicitly saving.

#### Safety and data
- Detection runs locally against the existing transaction database; no external service or new permission is used.
- Detection is read-only. It does not create schedules, post transactions, or change account balances automatically.
- No database schema migration is required.

#### Verification
- Add unit tests for monthly and fortnightly cadence, minimum occurrence count, duplicate same-day entries, unstable amounts, irregular intervals, excluded transfers/recurring entries, and account separation.
- Add repository tests for suggestion metadata, existing-schedule suppression, and inactive-account exclusion.

### Stage 6A — Offline Merchant Recognition and Smarter Categorisation (2026-11-10)

#### Expanded merchant catalogue
- Expanded the offline directory from 57 starter entries to 1,075 distinct merchant records across eight spending categories.
- Added India-focused coverage for food outlets, supermarkets and quick-commerce, retail, mobility and fuel, telecom and utilities, entertainment, healthcare, and travel.
- Consolidated merchant names, category mappings and recognition aliases into `tool/data/merchant_catalog.json`, with generated Dart and Kotlin catalogues to prevent platform drift.
- Added catalogue-count and representative cross-category tests in both Flutter and Android.


#### Added
- Added an on-device merchant catalogue for over 1,000 India-focused merchants and payment descriptions across food delivery, groceries, shopping, travel, transport, utilities, entertainment, and health.
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
