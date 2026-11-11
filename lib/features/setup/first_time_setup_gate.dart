import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/first_time_setup_store.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../theme/artham_theme.dart';
import 'first_time_setup_screen.dart';

/// Shows first-time setup only when the device has no active bank accounts and
/// the user has not already completed or skipped the setup flow.
class FirstTimeSetupGate extends StatefulWidget {
  const FirstTimeSetupGate({
    super.key,
    required this.database,
    required this.child,
    this.store,
  });

  final AppDatabase database;
  final Widget child;
  final FirstTimeSetupStore? store;

  @override
  State<FirstTimeSetupGate> createState() => _FirstTimeSetupGateState();
}

class _FirstTimeSetupGateState extends State<FirstTimeSetupGate> {
  late final FirstTimeSetupStore _store =
      widget.store ?? LocalFirstTimeSetupStore();
  late final AccountRepository _accountRepository =
      AccountRepository(widget.database);
  late final TransactionRepository _transactionRepository =
      TransactionRepository(widget.database);

  bool? _showSetup;

  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    try {
      if (await _store.hasCompleted()) {
        if (mounted) setState(() => _showSetup = false);
        return;
      }

      final accounts = await _accountRepository.getActiveAccounts();
      if (accounts.isNotEmpty) {
        // Existing installations should not be interrupted by a new setup flow.
        await _prepareDefaultCategories();
        await _markCompletedSafely();
        if (mounted) setState(() => _showSetup = false);
        return;
      }
    } catch (error, stackTrace) {
      // Let the user proceed with setup even if the initial check cannot finish.
      debugPrint('Artham first-time setup check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (mounted) setState(() => _showSetup = true);
  }

  Future<void> _prepareDefaultCategories() async {
    try {
      await _transactionRepository.seedDefaultCategories();
    } catch (error, stackTrace) {
      // Category creation is retried when the user opens the transaction flow.
      debugPrint('Artham starter categories could not be created: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _markCompletedSafely() async {
    try {
      await _store.markCompleted();
    } catch (error, stackTrace) {
      // Do not block entry to the app if local marker storage is unavailable.
      debugPrint('Artham first-time setup marker could not be saved: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _finishSetup() async {
    await _prepareDefaultCategories();
    await _markCompletedSafely();

    if (mounted) setState(() => _showSetup = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSetup == null) {
      return const ArthamScaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_showSetup!) return widget.child;

    return FirstTimeSetupScreen(
      database: widget.database,
      onFinish: _finishSetup,
    );
  }
}
