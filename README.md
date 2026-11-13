# Artham

**Artham** is a Flutter-based personal finance app designed to help users manage their money, track transactions, monitor account balances, and stay on top of their budgets.

The app follows a **local-first architecture**, using Drift and SQLite to store financial data on the device.

> **Project status:** Public Android beta available; active development continues.


## Download for Android

**Latest Android beta — Artham v0.1.1.**

[**Download the APK**](https://github.com/vishnuwiz/artham/releases/download/v0.1.1/app-release.apk) · [View the GitHub release and release notes](https://github.com/vishnuwiz/artham/releases/tag/v0.1.1)

This is a beta build for Android. Install the downloaded APK on your device and review Android's install-source prompt when asked. Artham does not require SMS permissions; bank and UPI alerts can only be imported when you explicitly paste or share a message into the app.

## Features

### Implemented

- **Home dashboard** — View a summary of finances and account balances, with animated balance and monthly metric transitions.
- **Transaction management** — Record and manage income and expenses.
- **Transaction date and time** — Set or edit the date and time for income, expense and internal transfer records. The selected time is preserved when changing the date and is shown in transaction details.
- **Data export** — Share all transaction history as an Excel-friendly CSV, or create a structured JSON backup of the Drift tables. Legacy pending-SMS review records from older installations are preserved in backups when present. Exports are generated locally; JSON backups are unencrypted and should be stored securely.
- **Offline merchant recognition** — Recognise more than 1,000 India-focused merchants in transaction descriptions and bank SMS alerts using a local rule-based catalogue generated from a single version-controlled source. Suggest categories such as Restaurants, Food & Grocery, Shopping, Travel, Medical, Electricity, Internet & Telecom and Entertainment; users retain control to change the selected category. Recognised merchants are linked to transactions locally, while unknown payees are left unclassified.
- **Custom categories** — Manage expense and income categories in Settings > Categories. Built-in categories include Salary and the general Income category, plus Restaurants, Housing, Electricity, Transport & Fuel, Medical, Card Repayment, ATM and Loan. Each has a Material icon and colour. Add your own, rename or recolour any category, and hide ones you don't use; hidden categories keep their history.
- **Manual SMS import** — choose Activity > Import SMS, then paste or share an individual bank/UPI alert. Review the parsed fields and confirm before saving; local fingerprints prevent duplicate imports. Artham does not monitor incoming messages or scan the SMS inbox.
- **Live account balances** — Keep account balances updated as transactions change.
- **Internal transfers** — Transfer money between accounts while preserving the overall balance. Transfers use their own transaction type rather than appearing as income or expense categories.
- **Account history** — Review transactions associated with an account.
- **Bank account identification** — Display accounts throughout the app using the bank name and masked last four digits (for example, `Federal Bank · •••• 1255`) instead of requiring a separate account nickname. The same label is used in account cards, transaction details, account selectors, transfers, filters, recurring transactions, and SMS review.
- **Budgets** — Set overall and category-based monthly budgets, track spending progress, and carry positive unused balances forward when rollover is enabled.
- **Recurring budget templates** — Repeat overall or category budget limits each month. Templates can be paused or resumed; missing months are populated when the app opens, without creating transactions or changing account balances.
- **Budget performance** — Compare planned and actual spending for the overall budget and each category, review the remaining or exceeded amount, and view a six-month planned-versus-actual trend.
- **Predictive budget forecasts** — Estimate month-end spending from the average daily pace, identify budgets approaching or likely to exceed their limits, and show a daily spending guide for overall and category plans. Estimates appear after at least three elapsed days and recalculate when Insights is refreshed.
- **Automatic budget refresh** — Budget progress updates when relevant transactions change.
- **Activity screen** — Review, search, filter, and sort transaction activity. Home's Recent Transactions shortcut opens the full Activity screen.
- **Insights screen** — View financial insights, including animated spending-by-category charts and budget breakdowns.
- **Merchant spending insights** — Rank recognised merchants by current-month spend and flag unusual increases against the same day-of-month in the previous three completed months. Flags require sufficient history, a rise of more than 50%, and at least ₹500 above the usual amount.
- **Recurring transactions** — Create recurring income or expense schedules with daily, weekly, monthly, or yearly frequencies and a custom interval.
  - **Pattern suggestions** — Detect likely weekly, monthly, quarterly, half-yearly, and yearly payments from at least three similar local transactions. Review the proposed amount, account, category, frequency, and next expected date; Artham never creates a schedule or transaction from a detected pattern without your action.
  - Set a start date and an optional end date.
  - Pause, resume, or delete a schedule.
  - Review schedules that are due.
  - Confirm a due occurrence to add it to the normal transaction history.
  - Generated transactions are recorded with a recurring source and protected against duplicate generation for the same schedule occurrence.

### Platform notes

- SMS import is user-initiated on both Android and iOS. Artham does not request `RECEIVE_SMS` or `READ_SMS`, register an incoming-SMS receiver, or scan the message inbox. Only a message the user explicitly pastes or shares into Activity > Import SMS is processed.
- Bank statement import.
- Database encryption and additional security improvements.
- JSON backup restore/import (export is implemented first; restore is not included yet).
- Expanded Settings options.
- Further performance improvements.

## Tech Stack

| Area | Technology |
|---|---|
| App framework | Flutter |
| Programming language | Dart (Flutter app), Kotlin (Android activity entry point) |
| Local database | SQLite |
| Database toolkit | Drift |
| Data persistence | On-device / local-first |

## Database

Artham stores its data locally in an SQLite database.

- **Database file:** `artham.sqlite`
- **Drift database definition:** `lib/data/app_database.dart`
- **Generated database code:** `lib/data/app_database.g.dart`
- **Current schema version:** `5`

The database includes the following tables:

| Table | Purpose |
|---|---|
| `BankAccounts` | Stores account information |
| `Categories` | Stores built-in and custom transaction categories, with icon, colour and hidden state |
| `Merchants` | Stores merchant information |
| `MoneyTransactions` | Stores income, expense, transfer, and generated recurring transactions |
| `Budgets` | Stores monthly overall and category budget limits, including rollover settings |
| `BudgetTemplates` | Stores recurring monthly overall/category budget templates and their effective start month |
| `ProcessedSms` | Stores local fingerprints to prevent duplicate manual SMS imports |
| `RecurringSchedules` | Stores recurring transaction schedules and their next due dates |

Older installations may contain an auxiliary Android-only `pending_sms_imports` table from the retired automatic-SMS feature. Current versions do not create or consume pending rows; existing rows are left untouched and included in JSON backups for data-preservation compatibility.

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
│   ├── data_export_service.dart
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
- Maintain `tool/data/merchant_catalog.json` as the single source of truth for merchant names, categories and aliases. Run `python tool/generate_merchant_catalog.py` after edits and `python tool/generate_merchant_catalog.py --check` to verify the generated Dart catalogue; recognition must remain on-device and deterministic.
- Prefer an explicit payee/counterparty extracted from a manually imported bank alert over provider names elsewhere in the SMS.
- Keep account balances consistent when creating, editing, or deleting transactions.
- Display saved bank accounts using the bank name and masked last four digits; do not depend on a user-entered nickname for account identification.
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

The beta launcher artwork is stored in `assets/branding/` and generated for Android and iOS. The animated Flutter startup screen is implemented in `lib/splash/artham_splash.dart`; it draws the pastel A mark, rupee coin, BETA ribbon, Malayalam wordmark, and tagline. Native launch screens use a matching lavender background.

After changing branding assets or icon configuration, run:

```powershell
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter analyze
flutter test
flutter build apk --release
```

The Android launcher resources and iOS AppIcon set are checked into the repository as well as being regenerated by CI.
