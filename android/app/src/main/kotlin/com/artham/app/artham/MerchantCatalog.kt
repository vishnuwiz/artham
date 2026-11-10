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
 * Rules are generated from tool/data/merchant_catalog.json, the same source
 * used by the Flutter app. Matching uses normalized whole tokens and checks
 * longer aliases first.
 */
internal object MerchantCatalog {
    private data class Alias(
        val name: String,
        val categoryName: String,
        val value: String,
    )

    val merchantCount: Int
        get() = MerchantCatalogData.rules.size

    private val aliases = MerchantCatalogData.rules.flatMap { rule ->
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
