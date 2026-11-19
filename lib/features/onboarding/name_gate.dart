import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/user_profile.dart';
import 'getting_started_screen.dart' show AC;

/// Asks for the user's name once, after Getting Started, so Home can greet
/// them. Skipping is allowed and is remembered, so the question is not asked
/// again.
class NameGate extends StatefulWidget {
  const NameGate({super.key, required this.child, this.profile});

  final Widget child;
  final UserProfile? profile;

  @override
  State<NameGate> createState() => _NameGateState();
}

class _NameGateState extends State<NameGate> {
  bool? _asked;

  UserProfile get _profile => widget.profile ?? UserProfile.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _profile.load();
    if (!mounted) return;
    setState(() => _asked = _profile.asked);
  }

  Future<void> _done(String? name) async {
    await _profile.save(name);
    if (!mounted) return;
    setState(() => _asked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_asked == null) {
      return Scaffold(
        backgroundColor: AC.bg,
        body: Center(child: CircularProgressIndicator(color: AC.lavender)),
      );
    }
    if (_asked!) return widget.child;
    return NameScreen(onDone: _done);
  }
}

class NameScreen extends StatefulWidget {
  const NameScreen({super.key, required this.onDone});

  /// Called with the cleaned name, or null when the user skips.
  final ValueChanged<String?> onDone;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _controller = TextEditingController();
  final _greeting = greetingFor(DateTime.now());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = UserProfile.clean(_controller.text);
    if (name == null) return;
    HapticFeedback.selectionClick();
    widget.onDone(name);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: AC.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: -140,
            left: -120,
            child: _Glow(color: AC.lavender.withValues(alpha: 0.30), size: 420),
          ),
          Positioned(
            bottom: -160,
            right: -140,
            child: _Glow(color: AC.mint.withValues(alpha: 0.18), size: 420),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduce ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 18),
                      child: child,
                    ),
                  ),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final name = UserProfile.clean(value.text);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/branding/artham_app_icon_ios_1024.png',
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'What should we call you?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AC.text,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'We will greet you by name on your home screen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AC.textSoft, fontSize: 14),
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            key: const Key('name-field'),
                            controller: _controller,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            maxLength: UserProfile.maxNameLength,
                            onSubmitted: (_) => _submit(),
                            style: const TextStyle(
                              color: AC.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Your name',
                              hintStyle: TextStyle(
                                color: AC.textSoft.withValues(alpha: 0.6),
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(
                                  color: AC.lavender,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 30,
                            child: AnimatedSwitcher(
                              duration: reduce
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              child: Text(
                                name == null
                                    ? ''
                                    : '$_greeting, $name',
                                key: ValueKey(name ?? ''),
                                style: const TextStyle(
                                  color: AC.lavender,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              key: const Key('name-continue-button'),
                              onPressed: name == null ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AC.lavender,
                                foregroundColor: AC.bg,
                                disabledBackgroundColor: Colors.white
                                    .withValues(alpha: 0.10),
                                disabledForegroundColor: AC.textSoft,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            key: const Key('name-skip-button'),
                            onPressed: () => widget.onDone(null),
                            child: const Text(
                              'Skip for now',
                              style: TextStyle(
                                color: AC.textSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
