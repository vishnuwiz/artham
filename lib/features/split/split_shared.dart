import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/alerts/alert_engine.dart';
import '../../data/split/split_models.dart';
import '../../theme/artham_theme.dart';

/// Shared look and motion for the shared-money screens.

String splitMoney(int paise) => AlertEngine.formatRupees(paise);

/// Turns text such as "1,250.5" into paise, or null when it is not a positive
/// amount.
int? parseRupeesToPaise(String input) {
  final cleaned = input.replaceAll(RegExp(r'[₹,\s]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0 || value.isNaN || value.isInfinite) {
    return null;
  }
  return (value * 100).round();
}

const List<Color> splitAvatarColors = [
  ArthamColors.mint,
  Color(0xFF8CBEFF),
  ArthamColors.peach,
  ArthamColors.lavender,
  Color(0xFFFFA9C9),
  Color(0xFFA8E6FF),
];

Color avatarColorFor(SplitPerson? person) =>
    person == null
        ? ArthamColors.lavender
        : splitAvatarColors[person.colorIndex % splitAvatarColors.length];

bool reduceMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

/// A round initial. Shares a Hero tag with the same person on the next screen
/// so the avatar glides into the ledger header.
class SplitAvatar extends StatelessWidget {
  const SplitAvatar({
    super.key,
    required this.person,
    this.size = 44,
    this.label,
    this.hero = false,
  });

  final SplitPerson? person;
  final double size;

  /// Overrides the letter, e.g. "Y" for you.
  final String? label;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColorFor(person),
      ),
      child: Text(
        label ?? person?.initial ?? 'Y',
        style: TextStyle(
          color: ArthamColors.onAccent,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (!hero || person == null) return circle;
    return Hero(tag: 'split-avatar-${person!.id}', child: circle);
  }
}

/// Fades and lifts its child into place. Give list items increasing [index]
/// for a staggered entrance. Plays once, and not at all with reduce motion.
class AppearIn extends StatelessWidget {
  const AppearIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final delay = (index * 55).clamp(0, 440);
    final total = 380 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Counts from its previous value to a new one, so balances roll instead of
/// jumping.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({
    super.key,
    required this.paise,
    required this.style,
    this.prefix = '',
  });

  final int paise;
  final TextStyle style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return Text('$prefix${splitMoney(paise)}', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: paise.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) =>
          Text('$prefix${splitMoney(value.round())}', style: style),
    );
  }
}

/// Fade-and-slide page transition used for every shared-money screen.
Route<T> splitRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondary) => builder(context),
    transitionsBuilder: (context, animation, secondary, child) {
      if (reduceMotion(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A glass card used for rows and panels.
class SplitPanel extends StatelessWidget {
  const SplitPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.tint,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? ArthamColors.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? ArthamColors.line),
      ),
      child: child,
    );
  }
}

/// Small rounded back or close button used in screen headers.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? ArthamColors.lavender : ArthamColors.glass,
          ),
          child: Icon(
            icon,
            size: 20,
            color: filled ? ArthamColors.onAccent : ArthamColors.text,
          ),
        ),
      ),
    );
  }
}

/// The big lavender action button. Shows a small spinner while [busy].
class SplitPrimaryButton extends StatelessWidget {
  const SplitPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return AnimatedOpacity(
      opacity: onPressed == null ? 0.45 : 1,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: const LinearGradient(
                colors: [Color(0xFFCDB8FF), Color(0xFFA78AEF)],
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(height),
              onTap: enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    }
                  : null,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: busy
                      ? const SizedBox(
                          key: ValueKey('busy'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: ArthamColors.onAccent,
                          ),
                        )
                      : Text(
                          label,
                          key: ValueKey(label),
                          style: const TextStyle(
                            color: ArthamColors.onAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped choice chip with an animated fill.
class SplitChip extends StatelessWidget {
  const SplitChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? ArthamColors.lavender : ArthamColors.glass,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            color: selected ? ArthamColors.onAccent : ArthamColors.muted,
          ),
        ),
      ),
    );
  }
}

InputDecoration splitFieldDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: ArthamColors.glass,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: ArthamColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: ArthamColors.lavender, width: 1.5),
    ),
  );
}

/// Asks for a name and returns it, or null when cancelled.
Future<String?> askPersonName(BuildContext context) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ArthamColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ArthamColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Add a person',
            style: TextStyle(
              color: ArthamColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Only a name, saved on this phone. They never get anything from Artham.',
            style: TextStyle(color: ArthamColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('split-person-name'),
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: ArthamColors.text),
            decoration: splitFieldDecoration('Name'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          const SizedBox(height: 16),
          SplitPrimaryButton(
            label: 'Add person',
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    ),
  );
}
