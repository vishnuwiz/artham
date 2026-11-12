import 'package:material_ui/material_ui.dart';

import '../../data/onboarding_completion_store.dart';
import 'getting_started_screen.dart';

/// Shows Getting Started once, after the animated launch splash.
/// The completion marker is kept in app-private local storage.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _hasCompleted;

  @override
  void initState() {
    super.initState();
    _loadCompletionState();
  }

  Future<void> _loadCompletionState() async {
    final completed = await OnboardingCompletionStore.hasCompleted();
    if (!mounted) return;
    setState(() => _hasCompleted = completed);
  }

  Future<void> _finishOnboarding() async {
    try {
      await OnboardingCompletionStore.markCompleted();
    } catch (error, stackTrace) {
      // Do not block access to Artham if the marker cannot be written.
      debugPrint('Artham onboarding completion could not be saved: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;
    setState(() => _hasCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCompleted == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF17132A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFB8A9FF)),
        ),
      );
    }

    if (_hasCompleted!) return widget.child;

    return GettingStartedScreen(onGetStarted: _finishOnboarding);
  }
}
