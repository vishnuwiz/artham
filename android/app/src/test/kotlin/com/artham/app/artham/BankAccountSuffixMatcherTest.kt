package com.artham.app.artham

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BankAccountSuffixMatcherTest {
    @Test
    fun matchesMaskedAccountSuffix() {
        val result = BankAccountSuffixMatcher.matchSavedAccount(
            accounts = listOf(
                BankAccountSuffixMatcher.SavedAccount(11L, "1255"),
                BankAccountSuffixMatcher.SavedAccount(12L, "6983"),
            ),
            messageBody = "Your A/c XX1255 was debited by Rs. 500.",
        )

        assertTrue(result.accountSuffixFound)
        assertEquals(11L, result.accountId)
    }

    @Test
    fun matchesSuffixWhenAccountNumberIsShownInFull() {
        val result = BankAccountSuffixMatcher.matchSavedAccount(
            accounts = listOf(
                BankAccountSuffixMatcher.SavedAccount(21L, "9012"),
            ),
            messageBody = "A/c No. 1234-5678-9012 was credited.",
        )

        assertTrue(result.accountSuffixFound)
        assertEquals(21L, result.accountId)
    }

    @Test
    fun matchesSuffixFromSpacedFullAccountNumber() {
        assertEquals(
            "9012",
            BankAccountSuffixMatcher.extractLast4(
                "Account number 1234 5678 9012 was debited.",
            ),
        )
    }

    @Test
    fun matchesMaskedAccountNumberWithAsterisks() {
        assertEquals(
            "6983",
            BankAccountSuffixMatcher.extractLast4(
                "Your A/c No. ******6983 was debited.",
            ),
        )
    }

    @Test
    fun matchesAccountEndingWithDigits() {
        assertEquals(
            "6589",
            BankAccountSuffixMatcher.extractLast4(
                "Rs. 250 debited from account ending with 6589.",
            ),
        )
    }

    @Test
    fun normalizesSavedSuffixBeforeMatching() {
        assertEquals(
            "1255",
            BankAccountSuffixMatcher.normalizeSavedLast4("**** 12-55"),
        )
    }

    @Test
    fun leavesUnknownSuffixUnassignedInsteadOfGuessing() {
        val result = BankAccountSuffixMatcher.matchSavedAccount(
            accounts = listOf(BankAccountSuffixMatcher.SavedAccount(31L, "1255")),
            messageBody = "Your A/c XX9999 was debited by Rs. 500.",
        )

        assertTrue(result.accountSuffixFound)
        assertNull(result.accountId)
    }

    @Test
    fun leavesDuplicateSuffixesAmbiguous() {
        val result = BankAccountSuffixMatcher.matchSavedAccount(
            accounts = listOf(
                BankAccountSuffixMatcher.SavedAccount(41L, "1255"),
                BankAccountSuffixMatcher.SavedAccount(42L, "1255"),
            ),
            messageBody = "Your A/c XX1255 was debited by Rs. 500.",
        )

        assertTrue(result.accountSuffixFound)
        assertNull(result.accountId)
    }

    @Test
    fun doesNotMistakeLargeTransactionAmountForAnAccountSuffix() {
        assertNull(
            BankAccountSuffixMatcher.extractLast4(
                "Your account was debited by Rs. 12,500 at a shop.",
            ),
        )
    }

    @Test
    fun doesNotTreatAnUnlabelledUpiReferenceAsAnAccountNumber() {
        val result = BankAccountSuffixMatcher.matchSavedAccount(
            accounts = listOf(BankAccountSuffixMatcher.SavedAccount(51L, "9012")),
            messageBody = "Rs. 500 debited. UPI Ref No 123456789012.",
        )

        assertFalse(result.accountSuffixFound)
        assertNull(result.accountId)
    }
}
