#!/usr/bin/env python3
"""Generate the Dart and Kotlin merchant catalogue from the canonical JSON file."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tool" / "data" / "merchant_catalog.json"
DART_TARGET = ROOT / "lib" / "data" / "merchant_catalog_data.dart"
KOTLIN_TARGET = (
    ROOT / "android" / "app" / "src" / "main" / "kotlin"
    / "com" / "artham" / "app" / "artham" / "MerchantCatalogData.kt"
)
ALLOWED_CATEGORIES = {
    "Food & Dining", "Groceries", "Shopping", "Transportation",
    "Bills & Utilities", "Entertainment", "Health", "Travel",
}


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", value.lower())).strip()


def quote_dart(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return "'" + escaped + "'"


def quote_kotlin(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def validate(records: list[dict]) -> None:
    if len(records) < 500:
        raise ValueError(f"Expected at least 500 merchants; found {len(records)}")
    names: set[str] = set()
    aliases: dict[str, str] = {}
    for index, record in enumerate(records):
        name = record.get("name", "").strip()
        category = record.get("category", "")
        values = record.get("aliases", [])
        if not name or category not in ALLOWED_CATEGORIES or not values:
            raise ValueError(f"Invalid catalogue record at index {index}: {record!r}")
        normalized_name = normalize(name)
        if normalized_name in names:
            raise ValueError(f"Duplicate merchant name: {name}")
        names.add(normalized_name)
        for alias in values:
            key = normalize(alias)
            owner = aliases.get(key)
            if not key or (owner is not None and owner != name):
                raise ValueError(f"Empty or conflicting alias {alias!r}: {owner!r} / {name!r}")
            aliases[key] = name


def render_dart(records: list[dict]) -> str:
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Source: tool/data/merchant_catalog.json",
        "",
        "class MerchantCatalogEntry {",
        "  const MerchantCatalogEntry({",
        "    required this.name,",
        "    required this.categoryName,",
        "    required this.aliases,",
        "  });",
        "",
        "  final String name;",
        "  final String categoryName;",
        "  final List<String> aliases;",
        "}",
        "",
        "const List<MerchantCatalogEntry> merchantCatalogData = [",
    ]
    for record in records:
        aliases = ", ".join(quote_dart(alias) for alias in record["aliases"])
        lines.extend([
            "  MerchantCatalogEntry(",
            f"    name: {quote_dart(record['name'])},",
            f"    categoryName: {quote_dart(record['category'])},",
            f"    aliases: [{aliases}],",
            "  ),",
        ])
    lines.extend(["];", ""])
    return "\n".join(lines)


def render_kotlin(records: list[dict]) -> str:
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Source: tool/data/merchant_catalog.json",
        "",
        "package com.artham.app.artham",
        "",
        "internal data class MerchantCatalogRuleData(",
        "    val name: String,",
        "    val categoryName: String,",
        "    val aliases: List<String>,",
        ")",
        "",
        "internal object MerchantCatalogData {",
        "    val rules = listOf(",
    ]
    for record in records:
        aliases = ", ".join(quote_kotlin(alias) for alias in record["aliases"])
        lines.extend([
            "        MerchantCatalogRuleData(",
            f"            name = {quote_kotlin(record['name'])},",
            f"            categoryName = {quote_kotlin(record['category'])},",
            f"            aliases = listOf({aliases}),",
            "        ),",
        ])
    lines.extend(["    )", "}", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="fail if generated Dart/Kotlin files are stale")
    args = parser.parse_args()
    records = json.loads(SOURCE.read_text(encoding="utf-8"))
    validate(records)
    outputs = {
        DART_TARGET: render_dart(records),
        KOTLIN_TARGET: render_kotlin(records),
    }
    stale = []
    for target, content in outputs.items():
        if args.check:
            if not target.exists() or target.read_text(encoding="utf-8") != content:
                stale.append(str(target.relative_to(ROOT)))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
    if stale:
        print("Generated merchant catalogue files are stale: " + ", ".join(stale))
        return 1
    if args.check:
        print(f"Merchant catalogue is valid: {len(records)} merchants; generated files are current.")
    else:
        print(f"Generated Dart and Kotlin catalogues for {len(records)} merchants.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
