# Artham

**Artham** is a Flutter-based personal finance app designed to help users manage their money, track transactions, monitor account balances, and stay on top of their budgets.

The app follows a **local-first architecture**, using Drift and SQLite to store financial data on the device.

> **Project status:** Active development.

## Features

### Implemented

- **Home dashboard** — View a summary of finances and account balances.
- **Transaction management** — Record and manage income and expenses.
- **Offline merchant recognition** — Recognise more than 1,000 India-focused merchants in transaction descriptions and bank SMS alerts using a local rule-based catalogue generated from a single version-controlled source. Suggest categories such as Food & Dining, Groceries, Shopping, Travel, Health, Bills & Utilities and Entertainment; users retain control to change the selected category. Recognised merchants are linked to transactions locally, while unknown payees are left unclassified.
- **Automatic Android bank-SMS import (Android emulator validated; physical-device testing pending)** — after the user enables it and grants SMS permission, newly received bank/UPI debit and credit alerts are parsed in the background and saved to the existing local database. The receiver uses the account suffix in the alert to match a saved account, ignores duplicate alerts, and does not retain the original SMS body. Alerts with an unknown or ambiguous account suffix wait in Settings for manual account assignment.
- **Manual SMS import fallback** — paste/share a bank or UPI alert, review the parsed fields, and import it with local duplicate protection.
- **Bank statement import (CSV/XLSX/XLS)** — select a statement file, choose the account, verify detected date/description/debit/credit columns, preview parsed rows, and explicitly confirm import. Existing matches are skipped; the original statement file is not retained.
- **Live account balances** — Keep account balances updated as transactions change.
- **Internal transfers** — Transfer money between accounts while preserving the overall balance.
- **Account history** — Review transactions associated with an account.
- **Bank account identification** — Display accounts throughout the app using the bank name and masked last four digits (for example, `Federal Bank · •••• 1255`) instead of requiring a separate account nickname. The same label is used in account cards, transaction details, account selectors, transfers, filters, recurring transactions, and SMS review.
- **Budgets** — Set overall and category-based monthly budgets, track spending progress, and carry positive unused balances forward when rollover is enabled.
- **Recurring budget templates** — Repeat overall or category budget limits each month. Templates can be paused or resumed; missing months are populated when the app opens, without creating transactions or changing account balances.
- **Budget performance** — Compare planned and actual spending for the overall budget and each category, review the remaining or exceeded amount, and view a six-month planned-versus-actual trend.
- **Predictive budget forecasts** — Estimate month-end spending from the average daily pace, identify budgets approaching or likely to exceed their limits, and show a daily spending guide for overall and category plans. Estimates appear after at least three elapsed days and recalculate when Insights is refreshed.
- **Automatic budget refresh** — Budget progress updates when relevant transactions change.
- **Activity screen** — Review, search, filter, and sort transaction activity.
- **Insights screen** — View financial insights.
- **Merchant spending insights** — Rank recognised merchants by current-month spend and flag unusual increases against the same day-of-month in the previous three completed months. Flags require sufficient history, a rise of more than 50%, and at least ₹500 above the usual amount.
- **Recurring transactions** — Create recurring income or expense schedules with daily, weekly, monthly, or yearly frequencies and a custom interval.
  - **Pattern suggestions** — Detect likely weekly, monthly, quarterly, half-yearly, and yearly payments from at least three similar local transactions. Review the proposed amount, account, category, frequency, and next expected date; Artham never creates a schedule or transaction from a detected pattern without your action.
  - Set a start date and an optional end date.
  - Pause, resume, or delete a schedule.
  - Review schedules that are due.
  - Confirm a due occurrence to add it to the normal transaction history.
  - Generated transactions are recorded with a recurring source and protected against duplicate generation for the same schedule occurrence.

### Platform notes

- Android automatic SMS import is opt-in and listens only for new incoming SMS broadcasts; it does not read or scan the existing inbox and does not request `READ_SMS`. `RECEIVE_SMS` is a hard-restricted Android permission. The flow has been validated in the Android emulator; physical-device testing and distribution checks remain outstanding. Distribution through Google Play requires the applicable SMS-based money-management declaration and review/approval; a sideloaded APK may not be allowlisted to hold this permission.
- iOS supports user-initiated SMS sharing/pasting only; ordinary third-party apps cannot read the full Messages inbox.
- PDF bank statement import.
- Database encryption and additional security improvements.
- Expanded Settings options.
- Further performance improvements.

## Tech Stack

| Area | Technology |
|---|---|
| App framework | Flutter |
| Programming language | Dart (Flutter app), Kotlin (Android SMS receiver) |
| Local database | SQLite |
| Database toolkit | Drift |
| Data persistence | On-device / local-first |

## Database

Artham stores its data locally in an SQLite database.

- **Database file:** `artham.sqlite`
- **Drift database definition:** `lib/data/app_database.dart`
- **Generated database code:** `lib/data/app_database.g.dart`
- **Current schema version:** `4`

The database includes the following tables:

| Table | Purpose |
|---|---|
| `BankAccounts` | Stores account information |
| `Categories` | Stores transaction categories |
| `Merchants` | Stores merchant information |
| `MoneyTransactions` | Stores income, expense, transfer, and generated recurring transactions |
| `Budgets` | Stores monthly overall and category budget limits, including rollover settings |
| `BudgetTemplates` | Stores recurring monthly overall/category budget templates and their effective start month |
| `ProcessedSms` | Tracks processed SMS records |
| `RecurringSchedules` | Stores recurring transaction schedules and their next due dates |

An auxiliary Android-only `pending_sms_imports` table stores structured transaction fields (never the original SMS body) when an alert cannot be matched safely to an account. Pending items are shown in Settings for account assignment.

**Amount storage:** Monetary amounts are stored as integer paise to avoid floating-point precision issues. For example, ₹100.00 is stored as `10000`.

> Keep generated Drift code in sync with the database definitions whenever the schema changes. Database migrations should preserve existing user data.

## Getting Started

### Prerequisites

Install the following before running the project:

- Flutter SDK
- Dart SDK (included with Flutter)
- Android Studio or Visual Studio Code
- An Android emulator or a connected device

### 1. Clone the repository

```bash
git clone https://github.com/vishnuwiz/artham.git
cd artham
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Generate Drift code

If generated database code needs to be refreshed after a schema change, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Check the project

```bash
flutter analyze
```

### 5. Run the app

```bash
flutter run
```

## Project Structure

The main application code is maintained under `lib/`.

```text
lib/
├── data/
│   ├── app_database.dart
│   ├── app_database.g.dart
│   └── repositories/
│       └── recurring_transaction_repository.dart
└── features/
    └── transactions/
        ├── activity_screen.dart
        └── recurring_transactions_screen.dart
```

Other screens, repositories, and features are maintained in their respective folders.

## Development Notes

- Store monetary values as integer paise, not floating-point rupees.
- Maintain `tool/data/merchant_catalog.json` as the single source of truth for merchant names, categories and aliases. Run `python tool/generate_merchant_catalog.py` after edits and `python tool/generate_merchant_catalog.py --check` to verify the generated Dart and Kotlin catalogues; recognition must remain on-device and deterministic.
- Prefer an explicit payee/counterparty extracted from a bank alert over provider names elsewhere in the SMS.
- Keep account balances consistent when creating, editing, or deleting transactions.
- Display saved bank accounts using the bank name and masked last four digits; do not depend on a user-entered nickname for account identification.
- Keep native Android SMS `DateTime` values in the Unix-seconds format expected by Drift, and keep auxiliary pending-queue timestamp conversions consistent with their Dart readers.
- Internal transfers should update the source and destination accounts without changing the user's overall net worth.
- Keep budget progress in sync with the transactions that contribute to each budget.
- Recurring budget templates create budget-limit rows only; they must never create financial transactions or alter account balances.
- Template edits apply from the selected effective month forward; previously generated monthly budgets remain historical snapshots.
- Apply templates when opening the relevant month. Never overwrite a budget that already exists for that month.
- Recurring schedules should generate transactions only when the user confirms a due occurrence.
- Prevent duplicate recurring transactions for the same schedule and due date.
- Regenerate Drift code after changing database definitions.
- Add a dated entry to `CHANGELOG.md` when a feature, fix, or notable change is included in a build.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a chronological record of app changes.

## Contributing

Artham is under active development. Contributions, bug reports, and suggestions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make your changes and test them.
4. Submit a pull request with a clear description of the changes.

## License

No license has been specified yet. Until a license is added to this repository, all rights are reserved by the project owner. Please contact the owner before redistributing or reusing the code.

---

**Repository:** [github.com/vishnuwiz/artham](https://github.com/vishnuwiz/artham)

## App icon and splash screen

The supplied pastel Artham artwork is used for Android and iOS launcher icons. Save `icon-1024.png` from the supplied branding ZIP as `assets/branding/artham_app_icon_ios_1024.png`. The native launch screen uses a soft lavender background, then the animated in-app intro in `lib/features/splash/artham_splash_pastel.dart` takes over. Regenerate platform assets with:

```powershell
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter analyze
flutter test
```

