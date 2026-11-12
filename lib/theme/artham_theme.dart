import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Artham's dark "glass" palette.
///
/// A deep purple ground carries the three logo colours: lavender (primary),
/// mint (income / on track) and peach (attention). Debits are shown in a soft
/// red. Surfaces are translucent so the background glows show through.
abstract final class ArthamColors {
  static const Color ink = Color(0xFF17132B);
  static const Color sheet = Color(0xFF241D45);

  static const Color text = Color(0xFFF4F1FF);
  static const Color muted = Color(0xFFB8B1D9);
  static const Color faint = Color(0xFF8E87B3);

  static const Color lavender = Color(0xFFB9A5F5);
  static const Color mint = Color(0xFF8FE3C4);
  static const Color peach = Color(0xFFFFD3A0);
  static const Color debit = Color(0xFFFF8F8F);

  /// Text and icons placed on a solid lavender, mint, peach or white fill.
  static const Color onAccent = Color(0xFF1A1433);

  static const Color glass = Color(0x1FFFFFFF);
  static const Color glassSoft = Color(0x12FFFFFF);
  static const Color line = Color(0x29FFFFFF);
  static const Color hero = Color(0x47B9A5F5);

  static const Color lavenderTint = Color(0x2EB9A5F5);
  static const Color mintTint = Color(0x298FE3C4);
  static const Color peachTint = Color(0x29FFD3A0);
  static const Color debitTint = Color(0x29FF8F8F);
  static const Color blueTint = Color(0x298CBEFF);

  static const Border glassBorder = Border.fromBorderSide(
    BorderSide(color: line),
  );

  /// Fill for cards, list entries and inputs.
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x38B9A5F5), Color(0x178FE3C4), Color(0x1FFFD3A0)],
    stops: [0, 0.6, 1],
  );

  /// Stronger fill for balance and summary cards.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x70B9A5F5), Color(0x338FE3C4), Color(0x47FFD3A0)],
    stops: [0, 0.62, 1],
  );

  /// Progress fill for budgets that are on track.
  static const LinearGradient onTrackGradient = LinearGradient(
    colors: [lavender, mint],
  );
}

ThemeData buildArthamTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ArthamColors.lavender,
        brightness: Brightness.dark,
      ).copyWith(
        primary: ArthamColors.lavender,
        onPrimary: ArthamColors.onAccent,
        secondary: ArthamColors.mint,
        onSecondary: ArthamColors.onAccent,
        tertiary: ArthamColors.peach,
        onTertiary: ArthamColors.onAccent,
        error: ArthamColors.debit,
        onError: ArthamColors.onAccent,
        surface: ArthamColors.sheet,
        onSurface: ArthamColors.text,
        onSurfaceVariant: ArthamColors.muted,
        outline: ArthamColors.line,
        outlineVariant: ArthamColors.line,
        primaryContainer: ArthamColors.lavenderTint,
        onPrimaryContainer: ArthamColors.text,
        secondaryContainer: ArthamColors.lavenderTint,
        onSecondaryContainer: ArthamColors.text,
        inverseSurface: ArthamColors.text,
        onInverseSurface: ArthamColors.onAccent,
      );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ArthamColors.ink,
    canvasColor: ArthamColors.sheet,
    fontFamily: 'Roboto',
    dividerColor: ArthamColors.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ArthamColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ArthamColors.glass,
      labelStyle: const TextStyle(color: ArthamColors.muted),
      hintStyle: const TextStyle(color: ArthamColors.faint),
      prefixIconColor: ArthamColors.muted,
      suffixIconColor: ArthamColors.muted,
      border: inputBorder(ArthamColors.line),
      enabledBorder: inputBorder(ArthamColors.line),
      focusedBorder: inputBorder(ArthamColors.lavender, 1.5),
      errorBorder: inputBorder(ArthamColors.debit),
      focusedErrorBorder: inputBorder(ArthamColors.debit, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ArthamColors.lavender,
        foregroundColor: ArthamColors.onAccent,
        shape: buttonShape,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ArthamColors.lavender,
        foregroundColor: ArthamColors.onAccent,
        elevation: 0,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ArthamColors.lavender,
        side: const BorderSide(color: ArthamColors.lavender),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ArthamColors.lavender),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ArthamColors.peach,
      foregroundColor: ArthamColors.onAccent,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      color: ArthamColors.glass,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ArthamColors.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ArthamColors.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: ArthamColors.line),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ArthamColors.sheet,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: ArthamColors.sheet,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ArthamColors.text,
      contentTextStyle: TextStyle(
        color: ArthamColors.onAccent,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: ArthamColors.line),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ArthamColors.lavender,
      linearTrackColor: ArthamColors.line,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: ArthamColors.muted,
      textColor: ArthamColors.text,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ArthamColors.glass,
      selectedColor: ArthamColors.lavenderTint,
      side: const BorderSide(color: ArthamColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArthamColors.onAccent
            : ArthamColors.text,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArthamColors.lavender
            : ArthamColors.line,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

/// The app ground: deep purple with lavender, mint and peach glows.
class ArthamBackground extends StatelessWidget {
  const ArthamBackground({super.key, this.child});

  final Widget? child;

  static const _glows = <(Alignment, double, Color)>[
    (Alignment(-1.1, -1.05), 1.25, Color(0xFF4F4285)),
    (Alignment(1.25, -0.1), 0.95, Color(0x408FE3C4)),
    (Alignment(-1.2, 0.5), 0.85, Color(0x38FFD3A0)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: ArthamColors.ink),
        for (final (center, radius, color) in _glows)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: center,
                radius: radius,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ?child,
      ],
    );
  }
}

/// A [Scaffold] drawn over [ArthamBackground].
///
/// Each route paints its own opaque ground, so pushed screens never show the
/// screen beneath them.
class ArthamScaffold extends StatelessWidget {
  const ArthamScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return ArthamBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      ),
    );
  }
}

/// A frosted panel: blurs whatever is behind it and adds a light edge.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.gradient = ArthamColors.glassGradient,
    this.padding,
    this.blur = 24,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Gradient gradient;
  final EdgeInsetsGeometry? padding;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: borderRadius,
            border: ArthamColors.glassBorder,
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

class ArthamTab {
  const ArthamTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Floating glass tab bar. Unselected tabs are white; the selected tab is a
/// white capsule carrying its icon and label in dark ink. The capsule slides
/// from tab to tab instead of fading in place.
class ArthamTabBar extends StatelessWidget {
  const ArthamTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ArthamTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const Duration slideDuration = Duration(milliseconds: 340);
  static const Curve slideCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: GlassPanel(
        borderRadius: const BorderRadius.all(Radius.circular(33)),
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 54,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / tabs.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: slideDuration,
                    curve: slideCurve,
                    left: selectedIndex * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: DecoratedBox(
                        key: ValueKey('artham-tab-capsule'),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(27)),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < tabs.length; index++)
                        Expanded(
                          child: _TabButton(
                            tab: tabs[index],
                            selected: index == selectedIndex,
                            onTap: () {
                              if (index != selectedIndex) {
                                HapticFeedback.selectionClick();
                              }
                              onSelected(index);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ArthamTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ArthamColors.onAccent : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(27),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: ArthamTabBar.slideDuration,
                curve: ArthamTabBar.slideCurve,
                builder: (context, value, _) =>
                    Icon(tab.icon, size: 22, color: value),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: ArthamTabBar.slideDuration,
                curve: ArthamTabBar.slideCurve,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Text(tab.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows one of [children] at a time, like an [IndexedStack], but cross-fades
/// and nudges the pages sideways in the direction of travel. Every page stays
/// mounted, so scroll positions and loaded data are preserved. Pages that are
/// not visible are offstage and have their tickers muted.
class ArthamTabSwitcher extends StatefulWidget {
  const ArthamTabSwitcher({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 320),
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<ArthamTabSwitcher> createState() => _ArthamTabSwitcherState();
}

class _ArthamTabSwitcherState extends State<ArthamTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late int _from = widget.index;
  late int _to = widget.index;

  @override
  void didUpdateWidget(covariant ArthamTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _from = _to;
      _to = widget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final animating = _controller.value < 1 && _from != _to;
        final direction = _to >= _from ? 1.0 : -1.0;
        const shift = 0.06;

        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _slot(
                index: i,
                opacity: i == _to
                    ? (animating ? t : 1.0)
                    : (animating && i == _from ? 1 - t : 0.0),
                dx: i == _to
                    ? (animating ? (1 - t) * direction * shift : 0.0)
                    : (animating && i == _from ? -t * direction * shift : 0.0),
                visible: i == _to || (animating && i == _from),
              ),
          ],
        );
      },
    );
  }

  Widget _slot({
    required int index,
    required double opacity,
    required double dx,
    required bool visible,
  }) {
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: index != _to,
          child: RepaintBoundary(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: FractionalTranslation(
                translation: Offset(dx, 0),
                child: widget.children[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
