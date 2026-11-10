package com.artham.app.artham

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MerchantCatalogTest {
    @Test
    fun recognisesMerchantInUpiDescription() {
        val result = MerchantCatalog.recognize("UPI/DR/123456789/SWIGGY*ORDER123")

        assertEquals("Swiggy", result?.name)
        assertEquals("Food & Dining", result?.categoryName)
    }

    @Test
    fun prefersSpecificLongerAliasForInstamart() {
        val result = MerchantCatalog.recognize("SWIGGY INSTAMART ORDER 456")

        assertEquals("Swiggy Instamart", result?.name)
        assertEquals("Groceries", result?.categoryName)
    }

    @Test
    fun recognisesCommonMerchantsAcrossCategories() {
        val cases = mapOf(
            "Blinkit order" to ("Blinkit" to "Groceries"),
            "AMAZON PAY" to ("Amazon" to "Shopping"),
            "Uber trip" to ("Uber" to "Transportation"),
            "Netflix subscription" to ("Netflix" to "Entertainment"),
            "KSEB bill payment" to ("KSEB" to "Bills & Utilities"),
            "Tata 1mg order" to ("Tata 1mg" to "Health"),
            "MakeMyTrip booking" to ("MakeMyTrip" to "Travel"),
        )

        cases.forEach { (input, expected) ->
            val result = MerchantCatalog.recognize(input)
            assertEquals(input, expected.first, result?.name)
            assertEquals(input, expected.second, result?.categoryName)
        }
    }

    @Test
    fun matchingUsesWholeTokensRatherThanPartialWords() {
        assertNull(MerchantCatalog.recognize("Solar equipment payment"))
        assertNull(MerchantCatalog.recognize("Net amount transferred"))
        assertNull(MerchantCatalog.recognize("My Netflixx account"))
    }

    @Test
    fun leavesUnknownOrEmptyDescriptionsUnrecognised() {
        assertNull(MerchantCatalog.recognize("UPI payment to Local Book Store"))
        assertNull(MerchantCatalog.recognize(null))
        assertNull(MerchantCatalog.recognize("  "))
    }

    @Test
    fun returnsTheAliasThatMatched() {
        val result = MerchantCatalog.recognize("PAYMENT TO JIO MART")

        assertTrue(result != null)
        assertFalse(result!!.matchedAlias.isBlank())
        assertEquals("jio mart", result.matchedAlias)
    }
}
