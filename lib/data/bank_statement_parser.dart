class StatementColumnMapping {
  final int dateColumn;
  final int descriptionColumn;
  final int? debitColumn;
  final int? creditColumn;
  final int? amountColumn;
  final int? typeColumn;
  final int? referenceColumn;

  const StatementColumnMapping({
    required this.dateColumn,
    required this.descriptionColumn,
    this.debitColumn,
    this.creditColumn,
    this.amountColumn,
    this.typeColumn,
    this.referenceColumn,
  });

  StatementColumnMapping copyWith({
    int? dateColumn,
    int? descriptionColumn,
    int? debitColumn,
    int? creditColumn,
    int? amountColumn,
    int? typeColumn,
    int? referenceColumn,
    bool clearDebitColumn = false,
    bool clearCreditColumn = false,
    bool clearAmountColumn = false,
    bool clearTypeColumn = false,
    bool clearReferenceColumn = false,
  }) {
    return StatementColumnMapping(
      dateColumn: dateColumn ?? this.dateColumn,
      descriptionColumn: descriptionColumn ?? this.descriptionColumn,
      debitColumn: clearDebitColumn ? null : debitColumn ?? this.debitColumn,
      creditColumn: clearCreditColumn ? null : creditColumn ?? this.creditColumn,
      amountColumn: clearAmountColumn ? null : amountColumn ?? this.amountColumn,
      typeColumn: clearTypeColumn ? null : typeColumn ?? this.typeColumn,
      referenceColumn:
          clearReferenceColumn ? null : referenceColumn ?? this.referenceColumn,
    );
  }
}

class StatementTransaction {
  final DateTime transactionDate;
  final String description;
  final int amountPaise;
  final String transactionType;
  final String? referenceNumber;

  const StatementTransaction({
    required this.transactionDate,
    required this.description,
    required this.amountPaise,
    required this.transactionType,
    this.referenceNumber,
  });
}

class StatementParsingResult {
  final List<StatementTransaction> transactions;
  final int skippedRows;
  final int totalRows;
  final String? configurationError;

  const StatementParsingResult({
    required this.transactions,
    required this.skippedRows,
    required this.totalRows,
    this.configurationError,
  });
}

class BankStatementParser {
  static const int maximumRows = 10000;

  static int detectHeaderRow(List<List<String>> rows) {
    var bestIndex = 0;
    var bestScore = -1;
    final count = rows.length < 10 ? rows.length : 10;

    for (var index = 0; index < count; index++) {
      final mapping = detectMapping(rows[index]);
      var score = 0;
      if (mapping.dateColumn >= 0) score += 2;
      if (mapping.descriptionColumn >= 0) score += 2;
      if (mapping.debitColumn != null || mapping.creditColumn != null) {
        score += 2;
      } else if (mapping.amountColumn != null) {
        score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    return bestScore >= 4 ? bestIndex : 0;
  }

  static StatementColumnMapping detectMapping(List<String> headers) {
    final normalized = headers.map(_normalizeHeader).toList();
    int find(Set<String> exact, {List<String> contains = const []}) {
      for (var i = 0; i < normalized.length; i++) {
        if (exact.contains(normalized[i]) ||
            contains.any((part) => normalized[i].contains(part))) {
          return i;
        }
      }
      return -1;
    }

    final date = find(
      {'date', 'transactiondate', 'txndate', 'valuedate', 'postingdate'},
      contains: ['transactiondate', 'valuedate', 'postingdate'],
    );
    final description = find(
      {
        'description',
        'narration',
        'particulars',
        'details',
        'transactiondetails',
        'remarks',
      },
      contains: ['narration', 'particular', 'description', 'transactiondetail'],
    );
    final debit = find(
      {'debit', 'debitamount', 'withdrawal', 'withdrawals', 'dr', 'amountdebited'},
      contains: ['debit', 'withdrawal', 'amountdebited'],
    );
    final credit = find(
      {'credit', 'creditamount', 'deposit', 'deposits', 'cr', 'amountcredited'},
      contains: ['credit', 'deposit', 'amountcredited'],
    );
    final amount = find(
      {'amount', 'transactionamount', 'txnamount'},
      contains: ['transactionamount', 'txnamount'],
    );
    final type = find(
      {'type', 'drcr', 'transactiontype', 'debitcredit'},
      contains: ['transactiontype', 'drcr'],
    );
    final reference = find(
      {
        'reference',
        'referencenumber',
        'referenceno',
        'refno',
        'utr',
        'rrn',
        'transactionid',
        'txnid',
        'chequeno',
      },
      contains: ['reference', 'utr', 'rrn', 'transactionid', 'txnid'],
    );
    final hasDebitCredit = debit >= 0 || credit >= 0;

    return StatementColumnMapping(
      dateColumn: date,
      descriptionColumn: description,
      debitColumn: debit >= 0 ? debit : null,
      creditColumn: credit >= 0 ? credit : null,
      amountColumn: amount >= 0 && !hasDebitCredit ? amount : null,
      typeColumn: type >= 0 ? type : null,
      referenceColumn: reference >= 0 ? reference : null,
    );
  }

  static StatementParsingResult parse({
    required List<String> headers,
    required List<List<String>> rows,
    required StatementColumnMapping mapping,
  }) {
    if (mapping.dateColumn < 0 || mapping.dateColumn >= headers.length) {
      return const StatementParsingResult(
        transactions: [],
        skippedRows: 0,
        totalRows: 0,
        configurationError: 'Choose the transaction date column.',
      );
    }
    if (mapping.descriptionColumn < 0 ||
        mapping.descriptionColumn >= headers.length) {
      return const StatementParsingResult(
        transactions: [],
        skippedRows: 0,
        totalRows: 0,
        configurationError: 'Choose the description or narration column.',
      );
    }
    final hasDebitCredit =
        mapping.debitColumn != null || mapping.creditColumn != null;
    final hasAmount = mapping.amountColumn != null;
    if (hasDebitCredit == hasAmount) {
      return const StatementParsingResult(
        transactions: [],
        skippedRows: 0,
        totalRows: 0,
        configurationError:
            'Map either Debit/Credit columns or one signed Amount column.',
      );
    }
    for (final column in [
      mapping.debitColumn,
      mapping.creditColumn,
      mapping.amountColumn,
      mapping.typeColumn,
      mapping.referenceColumn,
    ]) {
      if (column != null && (column < 0 || column >= headers.length)) {
        return const StatementParsingResult(
          transactions: [],
          skippedRows: 0,
          totalRows: 0,
          configurationError: 'A selected column is outside the statement.',
        );
      }
    }

    final transactions = <StatementTransaction>[];
    var skipped = 0;
    final boundedRows = rows.length > maximumRows
        ? rows.take(maximumRows).toList()
        : rows;

    for (final row in boundedRows) {
      if (row.every((value) => value.trim().isEmpty)) continue;
      final date = parseDate(_valueAt(row, mapping.dateColumn));
      final description = _valueAt(row, mapping.descriptionColumn).trim();
      if (date == null || description.isEmpty) {
        skipped++;
        continue;
      }

      String type;
      int amountPaise;
      if (hasDebitCredit) {
        final debit = mapping.debitColumn == null
            ? null
            : _parseMoney(_valueAt(row, mapping.debitColumn!));
        final credit = mapping.creditColumn == null
            ? null
            : _parseMoney(_valueAt(row, mapping.creditColumn!));
        if ((debit == null || debit.amountPaise == 0) &&
            (credit == null || credit.amountPaise == 0)) {
          skipped++;
          continue;
        }
        if ((debit?.amountPaise ?? 0) > 0 &&
            (credit?.amountPaise ?? 0) > 0) {
          skipped++;
          continue;
        }
        if ((debit?.amountPaise ?? 0) > 0) {
          type = 'expense';
          amountPaise = debit!.amountPaise;
        } else {
          type = 'income';
          amountPaise = credit!.amountPaise;
        }
      } else {
        final money = _parseMoney(_valueAt(row, mapping.amountColumn!));
        if (money == null || money.amountPaise <= 0) {
          skipped++;
          continue;
        }
        final typeText = mapping.typeColumn == null
            ? ''
            : _normalizeHeader(_valueAt(row, mapping.typeColumn!));
        if (typeText.isNotEmpty) {
          final direction = _directionFromType(typeText);
          if (direction == null) {
            skipped++;
            continue;
          }
          type = direction;
        } else if (money.explicitDirection != null) {
          type = money.explicitDirection!;
        } else if (money.isNegative) {
          type = 'expense';
        } else {
          skipped++;
          continue;
        }
        amountPaise = money.amountPaise;
      }

      if (amountPaise <= 0) {
        skipped++;
        continue;
      }
      final reference = mapping.referenceColumn == null
          ? null
          : _valueAt(row, mapping.referenceColumn!).trim();
      transactions.add(
        StatementTransaction(
          transactionDate: date,
          description: description,
          amountPaise: amountPaise,
          transactionType: type,
          referenceNumber: reference == null || reference.isEmpty
              ? null
              : reference,
        ),
      );
    }

    return StatementParsingResult(
      transactions: transactions,
      skippedRows: skipped + (rows.length - boundedRows.length),
      totalRows: rows.length,
    );
  }

  static DateTime? parseDate(String raw) {
    final value = raw.trim().replaceAll('\uFEFF', '');
    if (value.isEmpty) return null;

    final serial = double.tryParse(value);
    if (serial != null && serial >= 20000 && serial <= 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    }

    final iso = RegExp(r'^(20\d{2})-(\d{1,2})-(\d{1,2})$')
        .firstMatch(value);
    if (iso != null) {
      return _safeDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final numeric = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$',
    ).firstMatch(value);
    if (numeric != null) {
      var year = int.parse(numeric.group(3)!);
      if (year < 100) year += 2000;
      return _safeDate(
        year,
        int.parse(numeric.group(2)!),
        int.parse(numeric.group(1)!),
      );
    }

    final named = RegExp(
      r'^(\d{1,2})[ -]([A-Za-z]{3,9})[ ,.-]+(\d{2,4})$',
      caseSensitive: false,
    ).firstMatch(value);
    if (named != null) {
      const months = {
        'jan': 1, 'january': 1, 'feb': 2, 'february': 2,
        'mar': 3, 'march': 3, 'apr': 4, 'april': 4, 'may': 5,
        'jun': 6, 'june': 6, 'jul': 7, 'july': 7, 'aug': 8,
        'august': 8, 'sep': 9, 'sept': 9, 'september': 9,
        'oct': 10, 'october': 10, 'nov': 11, 'november': 11,
        'dec': 12, 'december': 12,
      };
      final month = months[named.group(2)!.toLowerCase()];
      if (month != null) {
        var year = int.parse(named.group(3)!);
        if (year < 100) year += 2000;
        return _safeDate(year, month, int.parse(named.group(1)!));
      }
    }

    final parsed = DateTime.tryParse(value);
    if (parsed != null && parsed.year >= 2000 && parsed.year <= 2100) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return null;
  }

  static _ParsedMoney? _parseMoney(String raw) {
    final value = raw.trim().replaceAll(',', '').replaceAll('₹', '');
    if (value.isEmpty || value == '-' || value == '—') return null;

    final upper = value.toUpperCase();
    final hasDr = RegExp(r'\bDR\b').hasMatch(upper) ||
        RegExp(r'DR$').hasMatch(upper);
    final hasCr = RegExp(r'\bCR\b').hasMatch(upper) ||
        RegExp(r'CR$').hasMatch(upper);
    if (hasDr && hasCr) return null;
    final explicitDirection = hasDr
        ? 'expense'
        : hasCr
            ? 'income'
            : null;
    final isNegative = value.contains('(') ||
        RegExp(r'^\s*-').hasMatch(value) ||
        RegExp(r'\bDR\b|DR$', caseSensitive: false).hasMatch(value);
    final match = RegExp(r'\d+(?:\.\d{1,2})?').firstMatch(value);
    if (match == null) return null;
    final number = double.tryParse(match.group(0)!);
    if (number == null || !number.isFinite) return null;
    return _ParsedMoney(
      amountPaise: (number * 100).round().abs(),
      isNegative: isNegative,
      explicitDirection: explicitDirection,
    );
  }

  static String? _directionFromType(String value) {
    if (RegExp(r'^(dr|debit|withdrawal|withdraw|paid|payment)$').hasMatch(value)) {
      return 'expense';
    }
    if (RegExp(r'^(cr|credit|deposit|deposited|received|receipt)$').hasMatch(value)) {
      return 'income';
    }
    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    if (year < 2000 || year > 2100 || month < 1 || month > 12) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static String _normalizeHeader(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _valueAt(List<String> row, int index) =>
      index >= 0 && index < row.length ? row[index] : '';
}

class _ParsedMoney {
  final int amountPaise;
  final bool isNegative;
  final String? explicitDirection;

  const _ParsedMoney({
    required this.amountPaise,
    required this.isNegative,
    required this.explicitDirection,
  });
}
