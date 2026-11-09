package com.artham.app.artham

import android.content.ContentValues
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.provider.Telephony
import android.util.Log
import io.flutter.util.PathUtils
import java.io.File
import java.util.Calendar
import java.util.Locale

/**
 * Receives only new SMS broadcasts. It never scans the user's SMS inbox.
 *
 * The app database is opened through Flutter's application-data directory so
 * transactions are written to the same local Drift database used by the UI.
 */
class BankSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val preferences = context.getSharedPreferences(
            PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
        if (!preferences.getBoolean(KEY_ENABLED, false)) return

        val smsParts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (smsParts.isNullOrEmpty()) return

        val body = smsParts.joinToString(separator = "") {
            it.messageBody.orEmpty()
        }.trim()
        if (body.isEmpty()) return

        val sender = smsParts.firstOrNull()?.originatingAddress.orEmpty()
        val receivedAt = smsParts.maxOfOrNull { it.timestampMillis }
            ?: System.currentTimeMillis()
        val parsed = parseTransaction(body, receivedAt) ?: return
        val defaultAccountId = preferences.getLong(KEY_DEFAULT_ACCOUNT_ID, -1L)

        // Database access is disk I/O. Keep it off the broadcast main thread
        // while completing the broadcast within Android's receiver time limit.
        val pendingResult = goAsync()
        Thread {
            try {
                processParsedSms(
                    context = context.applicationContext,
                    body = body,
                    sender = sender,
                    receivedAt = receivedAt,
                    parsed = parsed,
                    defaultAccountId = defaultAccountId,
                )
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    private fun processParsedSms(
        context: Context,
        body: String,
        sender: String,
        receivedAt: Long,
        parsed: ParsedTransaction,
        defaultAccountId: Long,
    ) {
        val databaseFile = File(
            PathUtils.getDataDirectory(context),
            DATABASE_NAME,
        )
        // The database is created by the app on first launch. Do not create a
        // second, incomplete database if the app has not been initialized.
        if (!databaseFile.isFile) return

        var database: SQLiteDatabase? = null
        try {
            database = SQLiteDatabase.openDatabase(
                databaseFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            )
            database.setForeignKeyConstraintsEnabled(true)
            // PRAGMA busy_timeout returns a result row on Android SQLite.
            // Use rawQuery rather than execSQL, which only supports statements
            // that do not return rows.
            database.rawQuery("PRAGMA busy_timeout = 5000", null).use {
                it.moveToFirst()
            }

            val fingerprint = fingerprint(body)
            database.beginTransactionNonExclusive()
            try {
                createPendingTableIfNeeded(database)

                val alreadyImported = database.rawQuery(
                    "SELECT id FROM processed_sms WHERE fingerprint = ? LIMIT 1",
                    arrayOf(fingerprint),
                ).use { it.moveToFirst() }

                if (alreadyImported) {
                    database.delete(
                        PENDING_TABLE,
                        "fingerprint = ?",
                        arrayOf(fingerprint),
                    )
                    database.setTransactionSuccessful()
                    return
                }

                val accounts = readActiveAccounts(database)
                val accountId = resolveAccount(
                    accounts = accounts,
                    sender = sender,
                    body = body,
                    defaultAccountId = defaultAccountId,
                )

                if (accountId == null) {
                    savePendingSms(
                        database = database,
                        fingerprint = fingerprint,
                        sender = sender,
                        receivedAt = receivedAt,
                        parsed = parsed,
                    )
                    database.setTransactionSuccessful()
                    return
                }

                val categoryId = findOrCreateCategory(
                    database = database,
                    name = parsed.category,
                    type = parsed.type,
                )

                val processedValues = ContentValues().apply {
                    put("fingerprint", fingerprint)
                    // Drift DateTime columns store Unix timestamps in seconds.
                    put("received_at", DriftDateTime.secondsFromMillis(receivedAt))
                    put("is_processed", 1)
                }
                val processedId = database.insertWithOnConflict(
                    "processed_sms",
                    null,
                    processedValues,
                    SQLiteDatabase.CONFLICT_IGNORE,
                )

                if (processedId == -1L) {
                    database.delete(
                        PENDING_TABLE,
                        "fingerprint = ?",
                        arrayOf(fingerprint),
                    )
                    database.setTransactionSuccessful()
                    return
                }

                val transactionValues = ContentValues().apply {
                    put("account_id", accountId)
                    putNull("transfer_to_account_id")
                    if (categoryId == null) putNull("category_id")
                    else put("category_id", categoryId)
                    putNull("merchant_id")
                    put("amount_paise", parsed.amountPaise)
                    put("transaction_type", parsed.type)
                    put("description", parsed.description)
                    if (parsed.referenceNumber == null) putNull("reference_number")
                    else put("reference_number", parsed.referenceNumber)
                    // Drift DateTime columns store Unix timestamps in seconds.
                    put(
                        "transaction_date",
                        DriftDateTime.secondsFromMillis(parsed.transactionDate),
                    )
                    put("source", "sms")
                    putNull("notes")
                    put(
                        "created_at",
                        DriftDateTime.secondsFromMillis(System.currentTimeMillis()),
                    )
                }

                val transactionId = database.insert(
                    "money_transactions",
                    null,
                    transactionValues,
                )
                check(transactionId != -1L) {
                    "Could not save the parsed SMS transaction."
                }

                database.delete(
                    PENDING_TABLE,
                    "fingerprint = ?",
                    arrayOf(fingerprint),
                )
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
        } catch (error: Exception) {
            // Never log or retain the incoming SMS body. The exception itself
            // is safe to log and helps diagnose database/receiver failures.
            Log.e(LOG_TAG, "Unable to process an incoming bank SMS alert.", error)
        } finally {
            database?.close()
        }
    }

    private fun createPendingTableIfNeeded(database: SQLiteDatabase) {
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $PENDING_TABLE (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                fingerprint TEXT NOT NULL UNIQUE,
                sender TEXT NOT NULL,
                received_at INTEGER NOT NULL,
                amount_paise INTEGER NOT NULL,
                transaction_type TEXT NOT NULL,
                transaction_date INTEGER NOT NULL,
                reference_number TEXT,
                description TEXT NOT NULL,
                suggested_category TEXT NOT NULL
            )
            """.trimIndent(),
        )
    }

    private fun savePendingSms(
        database: SQLiteDatabase,
        fingerprint: String,
        sender: String,
        receivedAt: Long,
        parsed: ParsedTransaction,
    ) {
        val values = ContentValues().apply {
            put("fingerprint", fingerprint)
            put("sender", sender)
            put("received_at", receivedAt)
            put("amount_paise", parsed.amountPaise)
            put("transaction_type", parsed.type)
            put("transaction_date", parsed.transactionDate)
            if (parsed.referenceNumber == null) putNull("reference_number")
            else put("reference_number", parsed.referenceNumber)
            put("description", parsed.description)
            put("suggested_category", parsed.category)
        }
        database.insertWithOnConflict(
            PENDING_TABLE,
            null,
            values,
            SQLiteDatabase.CONFLICT_IGNORE,
        )
    }

    private data class AccountRow(
        val id: Long,
        val bankName: String,
        val accountLast4: String?,
    )

    private data class ParsedTransaction(
        val amountPaise: Long,
        val type: String,
        val transactionDate: Long,
        val referenceNumber: String?,
        val description: String,
        val category: String,
    )

    private fun readActiveAccounts(database: SQLiteDatabase): List<AccountRow> {
        val accounts = mutableListOf<AccountRow>()
        database.rawQuery(
            """
            SELECT id, bank_name, account_number_last4
            FROM bank_accounts
            WHERE is_active = 1
            ORDER BY bank_name
            """.trimIndent(),
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                accounts += AccountRow(
                    id = cursor.getLong(0),
                    bankName = cursor.getString(1),
                    accountLast4 = if (cursor.isNull(2)) null else cursor.getString(2),
                )
            }
        }
        return accounts
    }

    private fun resolveAccount(
        accounts: List<AccountRow>,
        sender: String,
        body: String,
        defaultAccountId: Long,
    ): Long? {
        if (accounts.isEmpty()) return null

        val suffixMatch = BankAccountSuffixMatcher.matchSavedAccount(
            accounts = accounts.map {
                BankAccountSuffixMatcher.SavedAccount(
                    id = it.id,
                    accountNumberLast4 = it.accountLast4,
                )
            },
            messageBody = body,
        )
        if (suffixMatch.accountSuffixFound) {
            // Do not guess by sender or default when the SMS explicitly names
            // an account suffix that is unknown or shared by multiple accounts.
            return suffixMatch.accountId
        }

        val searchableText = normalizeLetters(sender)
        val bankMatches = accounts.filter { account ->
            bankAliases(account.bankName).any { alias ->
                alias.length >= 2 && searchableText.contains(alias)
            }
        }
        if (bankMatches.size == 1) return bankMatches.first().id
        if (bankMatches.size > 1) return null

        // A default account is an explicit user choice for alerts that do not
        // identify an account. Never silently select the first account.
        return accounts.firstOrNull { it.id == defaultAccountId }?.id
    }

    private fun bankAliases(bankName: String): Set<String> {
        val normalized = normalizeLetters(bankName)
        val aliases = mutableSetOf(normalized)
        when {
            normalized.contains("statebankofindia") -> aliases += "sbi"
            normalized.contains("hdfc") -> aliases += "hdfc"
            normalized.contains("icici") -> aliases += "icici"
            normalized.contains("axis") -> aliases += "axis"
            normalized.contains("federal") -> aliases += "federal"
            normalized.contains("canara") -> aliases += "canara"
            normalized.contains("kotak") -> aliases += "kotak"
            normalized.contains("unionbank") -> aliases += "unionbank"
            normalized.contains("bankofbaroda") -> aliases += "bob"
            normalized.contains("punjabnational") -> aliases += "pnb"
        }
        return aliases.filter { it.isNotEmpty() }.toSet()
    }

    private fun normalizeLetters(value: String): String {
        return value.lowercase(Locale.ROOT).replace(Regex("[^a-z0-9]"), "")
    }

    private fun parseTransaction(
        body: String,
        receivedAt: Long,
    ): ParsedTransaction? {
        val otpPattern = Regex(
            """\b(?:OTP|one[- ]time password|verification code|security code)\b""",
            RegexOption.IGNORE_CASE,
        )
        if (otpPattern.containsMatchIn(body)) return null

        val debitPattern = Regex(
            """\b(?:debited|debit|withdrawn|withdrawal|spent|paid|purchase|purchased|sent|transferred out)\b""",
            RegexOption.IGNORE_CASE,
        )
        val creditPattern = Regex(
            """\b(?:credited|credit|deposited|received|refund(?:ed)?|cashback|transferred in)\b""",
            RegexOption.IGNORE_CASE,
        )
        val debit = debitPattern.find(body)
        val credit = creditPattern.find(body)
        if ((debit == null && credit == null) || (debit != null && credit != null)) {
            return null
        }

        val type = if (debit != null) "expense" else "income"
        val directionOffset = (debit ?: credit)!!.range.first
        val amountPattern = Regex(
            """(?:₹|\bINR\b|\bRs\.?\s*)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)""",
            RegexOption.IGNORE_CASE,
        )
        val amountMatches = amountPattern.findAll(body).toList()
        if (amountMatches.isEmpty()) return null

        val chosenAmount = amountMatches.minByOrNull {
            kotlin.math.abs(it.range.first - directionOffset)
        } ?: return null
        val normalizedAmount = chosenAmount.groupValues[1].replace(",", "")
        val amountParts = normalizedAmount.split(".")
        val rupees = amountParts[0].toLongOrNull() ?: return null
        val paiseText = (amountParts.getOrNull(1).orEmpty() + "00").take(2)
        val paise = paiseText.toLongOrNull() ?: return null
        val amountPaise = rupees * 100L + paise
        if (amountPaise <= 0L) return null

        val reference = Regex(
            """\b(?:UPI\s*Ref(?:erence)?(?:\s*(?:No\.?|Number))?|UTR(?:\s*(?:No\.?|Number))?|RRN|Ref(?:erence)?(?:\s*(?:No\.?|Number))?|Txn(?:\s*(?:ID|No\.?))?)\s*[:#-]?\s*([A-Z0-9]{6,})\b""",
            RegexOption.IGNORE_CASE,
        ).find(body)?.groupValues?.getOrNull(1)

        val description = extractCounterparty(body)
            ?: if (type == "expense") "Bank SMS expense" else "Bank SMS credit"

        return ParsedTransaction(
            amountPaise = amountPaise,
            type = type,
            transactionDate = extractDate(body) ?: receivedAt,
            referenceNumber = reference,
            description = description,
            category = suggestCategory(body, type),
        )
    }

    private fun extractDate(body: String): Long? {
        val iso = Regex("""\b(20\d{2})-(\d{1,2})-(\d{1,2})\b""").find(body)
        if (iso != null) {
            return safeDate(
                iso.groupValues[1].toInt(),
                iso.groupValues[2].toInt(),
                iso.groupValues[3].toInt(),
            )
        }

        val numeric = Regex(
            """\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b""",
        ).find(body)
        if (numeric != null) {
            var year = numeric.groupValues[3].toInt()
            if (year < 100) year += 2000
            return safeDate(
                year,
                numeric.groupValues[2].toInt(),
                numeric.groupValues[1].toInt(),
            )
        }

        val named = Regex(
            """\b(\d{1,2})[- ]([A-Za-z]{3,9})[- , ](\d{2,4})\b""",
            RegexOption.IGNORE_CASE,
        ).find(body)
        if (named != null) {
            val months = mapOf(
                "jan" to 1, "january" to 1, "feb" to 2, "february" to 2,
                "mar" to 3, "march" to 3, "apr" to 4, "april" to 4,
                "may" to 5, "jun" to 6, "june" to 6, "jul" to 7,
                "july" to 7, "aug" to 8, "august" to 8, "sep" to 9,
                "sept" to 9, "september" to 9, "oct" to 10,
                "october" to 10, "nov" to 11, "november" to 11,
                "dec" to 12, "december" to 12,
            )
            val month = months[named.groupValues[2].lowercase(Locale.ROOT)]
            if (month != null) {
                var year = named.groupValues[3].toInt()
                if (year < 100) year += 2000
                return safeDate(year, month, named.groupValues[1].toInt())
            }
        }
        return null
    }

    private fun safeDate(year: Int, month: Int, day: Int): Long? {
        if (year !in 2000..2100 || month !in 1..12) return null
        val calendar = Calendar.getInstance().apply {
            clear()
            set(year, month - 1, day, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (
            calendar.get(Calendar.YEAR) != year ||
            calendar.get(Calendar.MONTH) != month - 1 ||
            calendar.get(Calendar.DAY_OF_MONTH) != day
        ) {
            return null
        }
        return calendar.timeInMillis
    }

    private fun extractCounterparty(body: String): String? {
        val pattern = Regex(
            """\b(?:to|from|at)\s+([A-Za-z][A-Za-z0-9 .&@_-]{1,35}?)(?=\s+(?:on|via|ref|utr|rrn|txn|transaction|available|avl|bal(?:ance)?|for|using)\b|[,.;\n]|$)""",
            RegexOption.IGNORE_CASE,
        )
        for (match in pattern.findAll(body)) {
            val value = match.groupValues[1].trim()
            val lower = value.lowercase(Locale.ROOT)
            if (
                value.isNotEmpty() &&
                !lower.startsWith("your ") &&
                !lower.startsWith("a/c") &&
                !lower.startsWith("account ") &&
                !lower.startsWith("vpa ")
            ) {
                return value.take(36)
            }
        }
        return null
    }

    private fun suggestCategory(body: String, type: String): String {
        val lower = body.lowercase(Locale.ROOT)
        if (type == "income") {
            return when {
                lower.contains("salary") -> "Salary"
                lower.contains("interest") -> "Interest"
                lower.contains("business") -> "Business Income"
                else -> "Other Income"
            }
        }
        return when {
            Regex("""swiggy|zomato|restaurant|food|cafe|dining""").containsMatchIn(lower) ->
                "Food & Dining"
            Regex("""bigbasket|blinkit|zepto|grocery|supermarket""").containsMatchIn(lower) ->
                "Groceries"
            Regex("""amazon|flipkart|myntra|ajio|shopping|retail""").containsMatchIn(lower) ->
                "Shopping"
            Regex("""uber|ola|rapido|petrol|diesel|fuel|metro|bus|taxi""").containsMatchIn(lower) ->
                "Transportation"
            Regex("""airtel|jio|vodafone|electricity|recharge|broadband|gas bill""").containsMatchIn(lower) ->
                "Bills & Utilities"
            Regex("""netflix|spotify|bookmyshow|hotstar|movie|cinema""").containsMatchIn(lower) ->
                "Entertainment"
            Regex("""pharmacy|hospital|clinic|medical|medicine""").containsMatchIn(lower) ->
                "Health"
            Regex("""airline|flight|irctc|hotel booking|travel""").containsMatchIn(lower) ->
                "Travel"
            else -> "Other Expense"
        }
    }

    private fun findOrCreateCategory(
        database: SQLiteDatabase,
        name: String,
        type: String,
    ): Long? {
        database.rawQuery(
            "SELECT id FROM categories WHERE name = ? AND type = ? LIMIT 1",
            arrayOf(name, type),
        ).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }

        val values = ContentValues().apply {
            put("name", name)
            put("type", type)
            put("is_system", 1)
        }
        val insertedId = database.insert("categories", null, values)
        return if (insertedId > 0L) insertedId else null
    }

    /**
     * Must stay identical to smsMessageFingerprint() in Dart so a manually
     * imported copy and an automatically received copy cannot be duplicated.
     */
    private fun fingerprint(message: String): String {
        val normalized = message.trim()
            .lowercase(Locale.ROOT)
            .replace(Regex("\\s+"), " ")

        var forward = 0x345678L
        var reverse = 0x123456L
        for (character in normalized) {
            forward = (forward * 31L + character.code) and 0x7fffffffL
        }
        for (character in normalized.reversed()) {
            reverse = (reverse * 37L + character.code) and 0x7fffffffL
        }
        return forward.toString(16).padStart(8, '0') +
            reverse.toString(16).padStart(8, '0')
    }

    companion object {
        private const val LOG_TAG = "ArthamSmsReceiver"
        private const val DATABASE_NAME = "artham.sqlite"
        private const val PENDING_TABLE = "pending_sms_imports"
        private const val PREFERENCES_NAME = "artham_sms_import"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_DEFAULT_ACCOUNT_ID = "default_account_id"
    }
}

/**
 * Converts epoch milliseconds to the Unix timestamp unit used by Drift DateTime columns.
 *
 * Keep the pending SMS queue in milliseconds: its custom INTEGER fields are
 * explicitly read with DateTime.fromMillisecondsSinceEpoch in Dart.
 */
internal object DriftDateTime {
    fun secondsFromMillis(timestampMillis: Long): Long = timestampMillis / 1000L
}
