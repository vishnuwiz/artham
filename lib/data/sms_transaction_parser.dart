import 'merchant_intelligence.dart';

class ParsedSmsTransaction {
  final int amountPaise;
  final String transactionType;
  final DateTime? transactionDate;
  final String? referenceNumber;
  final String description;
  final String suggestedCategory;
  final String? merchantName;

  const ParsedSmsTransaction({
    required this.amountPaise,
    required this.transactionType,
    required this.transactionDate,
    required this.referenceNumber,
    required this.description,
    required this.suggestedCategory,
    this.merchantName,
  });
}

/// Parses common Indian bank and UPI transaction-alert formats.
///
/// This parser is deliberately conservative: messages without one clear
/// debit/credit direction and one currency amount are not imported.
class SmsTransactionParser {
  static final RegExp _debitPattern = RegExp(
    r'\b(?:debited|debit|withdrawn|withdrawal|spent|paid|purchase|purchased|sent|transferred out)\b',
    caseSensitive: false,
  );

  static final RegExp _creditPattern = RegExp(
    r'\b(?:credited|credit|deposited|received|refund(?:ed)?|cashback|transferred in)\b',
    caseSensitive: false,
  );

  static final RegExp _otpPattern = RegExp(
    r'\b(?:OTP|one[- ]time password|verification code|security code)\b',
    caseSensitive: false,
  );

  static final RegExp _amountPattern = RegExp(
    r'(?:₹|\bINR\b|\bRs\.?\s*)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _referencePattern = RegExp(
    r'\b(?:UPI\s*Ref(?:erence)?(?:\s*(?:No\.?|Number))?|UTR(?:\s*(?:No\.?|Number))?|RRN|Ref(?:erence)?(?:\s*(?:No\.?|Number))?|Txn(?:\s*(?:ID|No\.?))?)\s*[:#-]?\s*([A-Z0-9]{6,})\b',
    caseSensitive: false,
  );

  ParsedSmsTransaction? parse(String message) {
    final text = message.trim();
    if (text.isEmpty || _otpPattern.hasMatch(text)) return null;

    final debitMatch = _debitPattern.firstMatch(text);
    final creditMatch = _creditPattern.firstMatch(text);

    // Mixed direction language can describe reversals or account transfers.
    // Require the user to handle those messages manually.
    if ((debitMatch == null && creditMatch == null) ||
        (debitMatch != null && creditMatch != null)) {
      return null;
    }

    final transactionType = debitMatch != null ? 'expense' : 'income';
    final directionOffset = (debitMatch ?? creditMatch)!.start;

    final amountMatches = _amountPattern.allMatches(text).toList();
    if (amountMatches.isEmpty) return null;

    Match? chosenAmount;
    var smallestDistance = 1 << 30;
    for (final match in amountMatches) {
      final distance = (match.start - directionOffset).abs();
      if (distance < smallestDistance) {
        smallestDistance = distance;
        chosenAmount = match;
      }
    }

    if (chosenAmount == null) return null;
    final amountPaise = _parsePaise(chosenAmount.group(1)!);
    if (amountPaise == null || amountPaise <= 0) return null;

    final referenceNumber = _referencePattern
        .firstMatch(text)
        ?.group(1)
        ?.trim();

    // Merchant recognition is a local, deterministic lookup. It is only
    // applied to expenses; income counterparties require separate handling.
    final counterparty = _extractCounterparty(text);
    final merchant = transactionType == 'expense'
        ? MerchantIntelligence.recognize(counterparty) ??
              (counterparty == null
                  ? MerchantIntelligence.recognize(text)
                  : null)
        : null;
    final categorySource = transactionType == 'expense'
        ? counterparty ?? text
        : text;
    final suggestedCategory =
        merchant?.categoryName ??
        _suggestCategory(categorySource, transactionType);
    final description =
        merchant?.name ??
        counterparty ??
        (transactionType == 'expense' ? 'Bank SMS expense' : 'Bank SMS credit');

    return ParsedSmsTransaction(
      amountPaise: amountPaise,
      transactionType: transactionType,
      transactionDate: _extractDate(text),
      referenceNumber: referenceNumber,
      description: description,
      suggestedCategory: suggestedCategory,
      merchantName: merchant?.name,
    );
  }

  int? _parsePaise(String value) {
    final normalized = value.replaceAll(',', '');
    final parts = normalized.split('.');
    final rupees = int.tryParse(parts.first);
    if (rupees == null) return null;
    final paiseText = parts.length > 1
        ? ('${parts[1]}00').substring(0, 2)
        : '00';
    final paise = int.tryParse(paiseText);
    if (paise == null) return null;
    return rupees * 100 + paise;
  }

  DateTime? _extractDate(String text) {
    final iso = RegExp(r'\b(20\d{2})-(\d{1,2})-(\d{1,2})\b').firstMatch(text);
    if (iso != null) {
      return _safeDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final numeric = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b')
        .firstMatch(text);
    if (numeric != null) {
      var year = int.parse(numeric.group(3)!);
      if (year < 100) year += 2000;
      return _safeDate(
        year,
        int.parse(numeric.group(2)!),
        int.parse(numeric.group(1)!),
      );
    }

    final namedMonth = RegExp(
      r'\b(\d{1,2})[- ]([A-Za-z]{3,9})[- , ](\d{2,4})\b',
    ).firstMatch(text);
    if (namedMonth != null) {
      const months = {
        'jan': 1,
        'january': 1,
        'feb': 2,
        'february': 2,
        'mar': 3,
        'march': 3,
        'apr': 4,
        'april': 4,
        'may': 5,
        'jun': 6,
        'june': 6,
        'jul': 7,
        'july': 7,
        'aug': 8,
        'august': 8,
        'sep': 9,
        'sept': 9,
        'september': 9,
        'oct': 10,
        'october': 10,
        'nov': 11,
        'november': 11,
        'dec': 12,
        'december': 12,
      };
      final month = months[namedMonth.group(2)!.toLowerCase()];
      if (month != null) {
        var year = int.parse(namedMonth.group(3)!);
        if (year < 100) year += 2000;
        return _safeDate(year, month, int.parse(namedMonth.group(1)!));
      }
    }

    return null;
  }

  DateTime? _safeDate(int year, int month, int day) {
    if (year < 2000 || year > 2100 || month < 1 || month > 12) {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String? _extractCounterparty(String text) {
    final matches = RegExp(
      r'\b(?:to|from|at)\s+([A-Za-z][A-Za-z0-9 .&@_-]{1,35}?)(?=\s+(?:on|via|ref|utr|rrn|txn|transaction|available|avl|bal(?:ance)?|for|using)\b|[,.;\n]|$)',
      caseSensitive: false,
    ).allMatches(text);

    for (final match in matches) {
      final value = match.group(1)?.trim();
      if (value == null || value.isEmpty) continue;

      final lower = value.toLowerCase();
      if (lower.startsWith('your ') ||
          lower.startsWith('a/c') ||
          lower.startsWith('account ') ||
          lower.startsWith('vpa ')) {
        continue;
      }
      return value.length > 36 ? value.substring(0, 36).trim() : value;
    }
    return null;
  }

  /// Suggests a category by name. Names match the built-in categories in
  /// `category_catalog.dart`; if the user has renamed or hidden one, the
  /// import screen falls back to its first category.
  String _suggestCategory(String text, String transactionType) {
    final lower = text.toLowerCase();
    if (transactionType == 'income') {
      if (lower.contains('salary')) return 'Income';
      if (RegExp(r'refund|reimburs|cashback').hasMatch(lower)) {
        return 'Reimbursement';
      }
      if (RegExp(r'interest|dividend|mutual fund|redemption').hasMatch(lower)) {
        return 'Investment';
      }
      if (lower.contains('business')) return 'Business';
      return 'Other';
    }

    if (RegExp(r'\batm\b|cash withdrawal|cash wdl').hasMatch(lower)) {
      return 'ATM';
    }
    if (RegExp(r'credit card (bill|payment|dues)|card repayment')
        .hasMatch(lower)) {
      return 'Card Repayment';
    }
    if (RegExp(r'\bemi\b|loan').hasMatch(lower)) {
      return 'Loan';
    }
    if (RegExp(r'swiggy|zomato|restaurant|food|cafe|dining').hasMatch(lower)) {
      return 'Restaurants';
    }
    if (RegExp(r'bigbasket|blinkit|zepto|grocery|supermarket')
        .hasMatch(lower)) {
      return 'Food & Grocery';
    }
    if (RegExp(r'amazon|flipkart|myntra|ajio|shopping|retail')
        .hasMatch(lower)) {
      return 'Shopping';
    }
    if (RegExp(r'uber|ola|rapido|petrol|diesel|fuel|metro|bus|taxi')
        .hasMatch(lower)) {
      return 'Transport & Fuel';
    }
    if (RegExp(r'electricity|kseb|power bill').hasMatch(lower)) {
      return 'Electricity';
    }
    if (RegExp(r'airtel|jio|vodafone|recharge|broadband|fibernet')
        .hasMatch(lower)) {
      return 'Internet & Telecom';
    }
    if (RegExp(r'gas bill|water bill|water authority').hasMatch(lower)) {
      return 'Utility';
    }
    if (RegExp(r'netflix|spotify|bookmyshow|hotstar|movie|cinema')
        .hasMatch(lower)) {
      return 'Entertainment';
    }
    if (RegExp(r'insurance|premium').hasMatch(lower)) {
      return 'Insurance';
    }
    if (RegExp(r'pharmacy|hospital|clinic|medical|medicine').hasMatch(lower)) {
      return 'Medical';
    }
    if (RegExp(r'airline|flight|irctc|hotel booking|travel').hasMatch(lower)) {
      return 'Travel';
    }
    return 'Other';
  }
}
