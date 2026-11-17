import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'split_models.dart';

/// Keeps the shared-money ledger in a small JSON file in app-private storage,
/// next to the alerts file. No database migration is needed.
class SplitStore {
  final Future<Directory> Function()? documentsDirectoryProvider;

  SplitStore({this.documentsDirectoryProvider});

  Future<File> _file() async {
    final provider = documentsDirectoryProvider;
    final documents = provider == null
        ? await getApplicationDocumentsDirectory()
        : await provider();
    return File(p.join(documents.path, 'Artham', 'split_ledger.json'));
  }

  Future<SplitLedger> load() async {
    final file = await _file();
    if (!await file.exists()) return const SplitLedger();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const SplitLedger();
      return SplitLedger.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // A damaged file must never stop the app from starting.
      return const SplitLedger();
    }
  }

  Future<void> save(SplitLedger ledger) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(ledger.toJson()),
      encoding: utf8,
      flush: true,
    );
  }
}
