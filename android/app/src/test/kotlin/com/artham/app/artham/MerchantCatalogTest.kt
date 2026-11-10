package com.artham.app.artham

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MerchantCatalogTest {
    @Test
    fun catalogueSupportsAtLeast500DistinctMerchants() {
        assertTrue("Expected at least 500 merchants", MerchantCatalog.merchantCount >= 500)
    }

    @Test
    fun recognisesEveryCanonicalMerchantAliasWithItsMappedCategory() {
        var testedAliases = 0

        MerchantCatalogData.rules.forEach { merchant ->
            merchant.aliases.forEach { alias ->
                val result = MerchantCatalog.recognize("UPI PAYMENT TO $alias")

                assertEquals("Alias: $alias", merchant.name, result?.name)
                assertEquals("Alias: $alias", merchant.categoryName, result?.categoryName)
                testedAliases++
            }
        }

        assertTrue("Expected at least 1,000 aliases", testedAliases >= 1000)
    }

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
            "Lulu Hypermarket purchase" to ("Lulu Hypermarket" to "Groceries"),
            "Decathlon store" to ("Decathlon" to "Shopping"),
            "Kochi Metro ticket" to ("Kochi Metro" to "Transportation"),
            "Kerala Vision Broadband" to ("Kerala Vision Broadband" to "Bills & Utilities"),
            "Amrita Hospital payment" to ("Amrita Hospital" to "Health"),
            "IndiGo flight" to ("IndiGo" to "Travel"),
            "Third Wave Coffee" to ("Third Wave Coffee" to "Food & Dining"),
            "ManoramaMAX subscription" to ("ManoramaMAX" to "Entertainment"),
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
