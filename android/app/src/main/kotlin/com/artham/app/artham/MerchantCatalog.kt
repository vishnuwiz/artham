package com.artham.app.artham

import java.util.Locale

internal data class MerchantMatch(
    val name: String,
    val categoryName: String,
    val matchedAlias: String,
)

/**
 * Offline merchant catalogue for the Android SMS receiver.
 *
 * Keep names, categories and aliases in sync with lib/data/merchant_intelligence.dart.
 * Matching uses normalized whole tokens and checks longer aliases first.
 */
internal object MerchantCatalog {
    private data class Rule(
        val name: String,
        val categoryName: String,
        val aliases: List<String>,
    )

    private data class Alias(
        val name: String,
        val categoryName: String,
        val value: String,
    )

    private val rules = listOf(
        Rule("Swiggy Instamart", "Groceries", listOf("swiggy instamart", "instamart")),
        Rule("Amazon Prime Video", "Entertainment", listOf("amazon prime video", "prime video")),
        Rule("JioMart", "Groceries", listOf("jiomart", "jio mart")),
        Rule("BigBasket", "Groceries", listOf("bigbasket", "big basket")),
        Rule("BookMyShow", "Entertainment", listOf("bookmyshow", "book my show")),
        Rule("MakeMyTrip", "Travel", listOf("makemytrip", "make my trip")),
        Rule("Reliance Digital", "Shopping", listOf("reliance digital")),
        Rule("Apollo Pharmacy", "Health", listOf("apollo pharmacy")),
        Rule("Amazon", "Shopping", listOf("amazon")),
        Rule("Flipkart", "Shopping", listOf("flipkart")),
        Rule("Myntra", "Shopping", listOf("myntra")),
        Rule("AJIO", "Shopping", listOf("ajio")),
        Rule("Meesho", "Shopping", listOf("meesho")),
        Rule("Nykaa", "Shopping", listOf("nykaa")),
        Rule("Croma", "Shopping", listOf("croma")),
        Rule("Swiggy", "Food & Dining", listOf("swiggy")),
        Rule("Zomato", "Food & Dining", listOf("zomato")),
        Rule("EatSure", "Food & Dining", listOf("eatsure", "eat sure")),
        Rule("Dominos", "Food & Dining", listOf("dominos", "domino s", "domino pizza")),
        Rule("Pizza Hut", "Food & Dining", listOf("pizza hut")),
        Rule("McDonalds", "Food & Dining", listOf("mcdonalds", "mcdonald", "mc donalds")),
        Rule("KFC", "Food & Dining", listOf("kfc")),
        Rule("Starbucks", "Food & Dining", listOf("starbucks")),
        Rule("Subway", "Food & Dining", listOf("subway")),
        Rule("Burger King", "Food & Dining", listOf("burger king")),
        Rule("Blinkit", "Groceries", listOf("blinkit")),
        Rule("Zepto", "Groceries", listOf("zepto")),
        Rule("DMart", "Groceries", listOf("dmart", "d mart")),
        Rule("Uber Eats", "Food & Dining", listOf("uber eats")),
        Rule("Uber", "Transportation", listOf("uber")),
        Rule("Ola", "Transportation", listOf("ola cabs", "ola")),
        Rule("Rapido", "Transportation", listOf("rapido")),
        Rule("Namma Yatri", "Transportation", listOf("namma yatri")),
        Rule("IRCTC", "Transportation", listOf("irctc")),
        Rule("RedBus", "Transportation", listOf("redbus", "red bus")),
        Rule("Indian Oil", "Transportation", listOf("indian oil", "indianoil", "iocl")),
        Rule("HPCL", "Transportation", listOf("hpcl", "hp petrol pump")),
        Rule("BPCL", "Transportation", listOf("bpcl", "bharat petroleum")),
        Rule("Shell", "Transportation", listOf("shell fuel", "shell petrol")),
        Rule("Airtel", "Bills & Utilities", listOf("airtel")),
        Rule("Jio", "Bills & Utilities", listOf("jio")),
        Rule("Vi", "Bills & Utilities", listOf("vodafone idea", "vi recharge")),
        Rule("KSEB", "Bills & Utilities", listOf("kseb", "kerala state electricity board")),
        Rule("BESCOM", "Bills & Utilities", listOf("bescom")),
        Rule("Netflix", "Entertainment", listOf("netflix")),
        Rule("Spotify", "Entertainment", listOf("spotify")),
        Rule("YouTube Premium", "Entertainment", listOf("youtube premium")),
        Rule("JioHotstar", "Entertainment", listOf("jiohotstar", "jio hotstar", "hotstar")),
        Rule("PVR INOX", "Entertainment", listOf("pvr inox", "pvr", "inox")),
        Rule("Tata 1mg", "Health", listOf("tata 1mg", "1mg")),
        Rule("PharmEasy", "Health", listOf("pharmeasy", "pharm easy")),
        Rule("Netmeds", "Health", listOf("netmeds")),
        Rule("Goibibo", "Travel", listOf("goibibo")),
        Rule("Cleartrip", "Travel", listOf("cleartrip")),
        Rule("Booking.com", "Travel", listOf("booking com")),
        Rule("Airbnb", "Travel", listOf("airbnb")),
        Rule("Agoda", "Travel", listOf("agoda")),
    )

    private val aliases = rules.flatMap { rule ->
        rule.aliases.map { alias ->
            Alias(
                name = rule.name,
                categoryName = rule.categoryName,
                value = normalize(alias),
            )
        }
    }.sortedByDescending { it.value.length }

    fun recognize(value: String?): MerchantMatch? {
        if (value.isNullOrBlank()) return null

        val normalized = " ${normalize(value)} "
        if (normalized.isBlank()) return null

        for (alias in aliases) {
            if (normalized.contains(" ${alias.value} ")) {
                return MerchantMatch(
                    name = alias.name,
                    categoryName = alias.categoryName,
                    matchedAlias = alias.value,
                )
            }
        }
        return null
    }

    private fun normalize(value: String): String {
        return value.lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9]+"), " ")
            .trim()
            .replace(Regex("\\s+"), " ")
    }
}
