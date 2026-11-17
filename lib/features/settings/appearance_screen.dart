import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/artham_theme.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/micro_interactions.dart';

/// Lets the user choose between the original Artham look and the flat Dark
/// and Light themes.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, ArthamThemeController? controller})
    : _controller = controller;

  final ArthamThemeController? _controller;

  @override
  Widget build(BuildContext context) {
    final controller = _controller ?? ArthamThemeController.instance;
    return ArthamScaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final active = controller.palette;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      key: const Key('appearance-back'),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Appearance',
                      style: TextStyle(
                        color: ArthamColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'THEME',
                  style: TextStyle(
                    color: ArthamColors.lavender,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < ArthamPalette.all.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FadeUp(
                      index: i,
                      child: _ThemeCard(
                        key: Key('theme-${ArthamPalette.all[i].id}'),
                        palette: ArthamPalette.all[i],
                        selected: ArthamPalette.all[i].id == active.id,
                        isDefault: ArthamPalette.all[i].id == 'artham',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.select(ArthamPalette.all[i]);
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Your choice is saved on this phone and applies everywhere in the app.',
                  style: TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fades and lifts a child in, one after another by [index].
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = index * 70;
    final total = 380 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    super.key,
    required this.palette,
    required this.selected,
    required this.isDefault,
    required this.onTap,
  });

  final ArthamPalette palette;
  final bool selected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 260);
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ArthamColors.glass,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? ArthamColors.lavender : ArthamColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _Preview(palette: palette),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        palette.name,
                        style: TextStyle(
                          color: ArthamColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ArthamColors.lavenderTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              color: ArthamColors.lavender,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    palette.description,
                    style: TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: duration,
              curve: Curves.easeOutBack,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ArthamColors.lavender,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 17,
                  color: ArthamColors.onAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny drawing of a screen in the given palette. It uses the palette's own
/// colours, not the active ones, so each card shows its own theme.
class _Preview extends StatelessWidget {
  const _Preview({required this.palette});

  final ArthamPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 92,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.ink,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
        gradient: palette.glows.isEmpty
            ? null
            : RadialGradient(
                center: palette.glows.first.$1 * 0.6,
                radius: 1.1,
                colors: [
                  palette.glows.first.$3,
                  palette.ink,
                ],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: palette.heroGradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 3,
                  decoration: BoxDecoration(
                    color: palette.onHeroMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 34,
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.onHero,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: palette.lavender,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: palette.mint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: palette.peach,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: palette.glass,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
}
