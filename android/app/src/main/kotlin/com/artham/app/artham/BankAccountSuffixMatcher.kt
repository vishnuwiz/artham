package com.artham.app.artham

/**
 * Extracts the final four account digits from the account identifier included
 * in a bank SMS. It requires account context or a masking marker so UPI
 * references, dates, balances and transaction amounts are not mistaken for an
 * account number.
 */
internal object BankAccountSuffixMatcher {
    data class SavedAccount(
        val id: Long,
        val accountNumberLast4: String?,
    )

    data class Match(
        val accountSuffixFound: Boolean,
        val accountId: Long?,
    )

    private val accountContextPatterns = listOf(
        Regex(
            """(?:\bA/C\b|\baccount\b(?:\s*(?:no\.?|number))?|\bacct\b(?:\s*(?:no\.?|number))?)[^0-9]{0,32}([0-9][0-9\s,-]{2,24}[0-9])(?=\D|$)""",
            RegexOption.IGNORE_CASE,
        ),
        Regex(
            """\bending(?:\s+with)?(?:\s+in)?[^0-9]{0,16}([0-9][0-9\s,-]{2,24}[0-9])(?=\D|$)""",
            RegexOption.IGNORE_CASE,
        ),
        Regex(
            """(?:\bX{2,}|(?:[*•]\s*){2,})[-\s]*([0-9][0-9\s,-]{2,24}[0-9])(?=\D|$)""",
            RegexOption.IGNORE_CASE,
        ),
    )

    fun matchSavedAccount(
        accounts: List<SavedAccount>,
        messageBody: String,
    ): Match {
        val messageLast4 = extractLast4(messageBody)
            ?: return Match(accountSuffixFound = false, accountId = null)

        val matches = accounts.filter {
            normalizeSavedLast4(it.accountNumberLast4) == messageLast4
        }

        // A suffix must identify exactly one saved account. Never guess when
        // no account matches or multiple accounts share the same final digits.
        return Match(
            accountSuffixFound = true,
            accountId = matches.singleOrNull()?.id,
        )
    }

    fun extractLast4(messageBody: String): String? {
        for (pattern in accountContextPatterns) {
            val accountNumber = pattern.find(messageBody)
                ?.groupValues
                ?.getOrNull(1)
                ?: continue
            val digits = accountNumber.filter(Char::isDigit)
            if (digits.length >= 4) return digits.takeLast(4)
        }
        return null
    }

    fun normalizeSavedLast4(value: String?): String? {
        val digits = value?.filter(Char::isDigit).orEmpty()
        return digits.takeIf { it.length >= 4 }?.takeLast(4)
    }
}
