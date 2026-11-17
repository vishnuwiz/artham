import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// One complete set of Artham colours. [ArthamPalette.artham] is the original
/// purple glass look and the default; [dark] and [light] are calmer, flatter
/// alternatives.
class ArthamPalette {
  const ArthamPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.ink,
    required this.sheet,
    required this.text,
    required this.muted,
    required this.faint,
    required this.lavender,
    required this.mint,
    required this.peach,
    required this.debit,
    required this.onAccent,
    required this.glass,
    required this.glassSoft,
    required this.line,
    required this.hero,
    required this.lavenderTint,
    required this.mintTint,
    required this.peachTint,
    required this.debitTint,
    required this.blueTint,
    required this.glassGradient,
    required this.heroGradient,
    required this.onHero,
    required this.onHeroMuted,
    required this.onHeroFaint,
    required this.onHeroLine,
    this.glows = const [],
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;

  final Color ink;
  final Color sheet;
  final Color text;
  final Color muted;
  final Color faint;
  final Color lavender;
  final Color mint;
  final Color peach;
  final Color debit;
  final Color onAccent;
  final Color glass;
  final Color glassSoft;
  final Color line;
  final Color hero;
  final Color lavenderTint;
  final Color mintTint;
  final Color peachTint;
  final Color debitTint;
  final Color blueTint;
  final LinearGradient glassGradient;
  final LinearGradient heroGradient;

  /// Text and lines placed on the hero (balance and summary) cards.
  final Color onHero;
  final Color onHeroMuted;
  final Color onHeroFaint;
  final Color onHeroLine;

  /// Soft coloured glows painted behind the app. Empty for flat themes.
  final List<(Alignment, double, Color)> glows;

  /// The original deep purple glass look.
  static const ArthamPalette artham = ArthamPalette(
    id: 'artham',
    name: 'Artham',
    description: 'The original deep purple glass look',
    brightness: Brightness.dark,
    ink: Color(0xFF17132B),
    sheet: Color(0xFF241D45),
    text: Color(0xFFF4F1FF),
    muted: Color(0xFFB8B1D9),
    faint: Color(0xFF8E87B3),
    lavender: Color(0xFFB9A5F5),
    mint: Color(0xFF8FE3C4),
    peach: Color(0xFFFFD3A0),
    debit: Color(0xFFFF8F8F),
    onAccent: Color(0xFF1A1433),
    glass: Color(0x1FFFFFFF),
    glassSoft: Color(0x12FFFFFF),
    line: Color(0x29FFFFFF),
    hero: Color(0x47B9A5F5),
    lavenderTint: Color(0x2EB9A5F5),
    mintTint: Color(0x298FE3C4),
    peachTint: Color(0x29FFD3A0),
    debitTint: Color(0x29FF8F8F),
    blueTint: Color(0x298CBEFF),
    glassGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x38B9A5F5), Color(0x178FE3C4), Color(0x1FFFD3A0)],
      stops: [0, 0.6, 1],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x70B9A5F5), Color(0x338FE3C4), Color(0x47FFD3A0)],
      stops: [0, 0.62, 1],
    ),
    onHero: Colors.white,
    onHeroMuted: Colors.white70,
    onHeroFaint: Colors.white60,
    onHeroLine: Colors.white24,
    glows: [
      (Alignment(-1.1, -1.05), 1.25, Color(0xFF4F4285)),
      (Alignment(1.25, -0.1), 0.95, Color(0x408FE3C4)),
      (Alignment(-1.2, 0.5), 0.85, Color(0x38FFD3A0)),
    ],
  );

  /// Clean, flat and dark.
  static const ArthamPalette dark = ArthamPalette(
    id: 'dark',
    name: 'Dark',
    description: 'Clean and flat, easy on the eyes at night',
    brightness: Brightness.dark,
    ink: Color(0xFF0F0F12),
    sheet: Color(0xFF1A1A1F),
    text: Color(0xFFF4F4F6),
    muted: Color(0xFFA0A0AC),
    faint: Color(0xFF82828E),
    lavender: Color(0xFFB9A5F5),
    mint: Color(0xFF6FD09A),
    peach: Color(0xFFFFB07A),
    debit: Color(0xFFFF8A8A),
    onAccent: Color(0xFF14101F),
    glass: Color(0xFF1C1C22),
    glassSoft: Color(0xFF17171C),
    line: Color(0xFF2B2B33),
    hero: Color(0xFF2A2447),
    lavenderTint: Color(0x33B9A5F5),
    mintTint: Color(0x296FD09A),
    peachTint: Color(0x29FFB07A),
    debitTint: Color(0x29FF8A8A),
    blueTint: Color(0x298CBEFF),
    glassGradient: LinearGradient(colors: [Color(0xFF1C1C22), Color(0xFF1C1C22)]),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2E2753), Color(0xFF211D38)],
    ),
    onHero: Color(0xFFF4F4F6),
    onHeroMuted: Color(0xFFB8B8C4),
    onHeroFaint: Color(0xFF9A9AA6),
    onHeroLine: Color(0x33FFFFFF),
  );

  /// Clean, flat and light.
  static const ArthamPalette light = ArthamPalette(
    id: 'light',
    name: 'Light',
    description: 'Bright, crisp and minimal for the daytime',
    brightness: Brightness.light,
    ink: Color(0xFFFFFFFF),
    sheet: Color(0xFFFFFFFF),
    text: Color(0xFF111114),
    muted: Color(0xFF6B6B76),
    faint: Color(0xFF7C7C88),
    lavender: Color(0xFF5B3FE0),
    mint: Color(0xFF1B7F46),
    peach: Color(0xFFB85F0C),
    debit: Color(0xFFC93737),
    onAccent: Color(0xFFFFFFFF),
    glass: Color(0xFFF4F4F7),
    glassSoft: Color(0xFFF9F9FB),
    line: Color(0xFFE4E4EA),
    hero: Color(0xFFEEEAFD),
    lavenderTint: Color(0x1F5B3FE0),
    mintTint: Color(0x1F1B7F46),
    peachTint: Color(0x24B85F0C),
    debitTint: Color(0x1FC93737),
    blueTint: Color(0x1F1F6FEB),
    glassGradient: LinearGradient(colors: [Color(0xFFF4F4F7), Color(0xFFF4F4F7)]),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEAE5FD), Color(0xFFF3F0FE)],
    ),
    onHero: Color(0xFF111114),
    onHeroMuted: Color(0xFF55555F),
    onHeroFaint: Color(0xFF6B6B76),
    onHeroLine: Color(0x26000000),
  );

  static const List<ArthamPalette> all = [artham, dark, light];

  static ArthamPalette byId(String? id) {
    for (final palette in all) {
      if (palette.id == id) return palette;
    }
    return artham;
  }
}

/// The colours the app is drawing with right now.
///
/// Every member reads the active [ArthamPalette], so switching the palette and
/// rebuilding the widget tree restyles the whole app. These are getters, not
/// constants, so they cannot be used inside `const` expressions.
abstract final class ArthamColors {
  static ArthamPalette _palette = ArthamPalette.artham;

  static ArthamPalette get palette => _palette;

  static void use(ArthamPalette palette) => _palette = palette;

  static bool get isDark => _palette.brightness == Brightness.dark;

  static Color get ink => _palette.ink;
  static Color get sheet => _palette.sheet;

  static Color get text => _palette.text;
  static Color get muted => _palette.muted;
  static Color get faint => _palette.faint;

  static Color get lavender => _palette.lavender;
  static Color get mint => _palette.mint;
  static Color get peach => _palette.peach;
  static Color get debit => _palette.debit;

  /// Text and icons placed on a solid lavender, mint, peach or white fill.
  static Color get onAccent => _palette.onAccent;

  static Color get glass => _palette.glass;
  static Color get glassSoft => _palette.glassSoft;
  static Color get line => _palette.line;
  static Color get hero => _palette.hero;

  static Color get lavenderTint => _palette.lavenderTint;
  static Color get mintTint => _palette.mintTint;
  static Color get peachTint => _palette.peachTint;
  static Color get debitTint => _palette.debitTint;
  static Color get blueTint => _palette.blueTint;

  /// Text and lines placed on the hero (balance and summary) cards.
  static Color get onHero => _palette.onHero;
  static Color get onHeroMuted => _palette.onHeroMuted;
  static Color get onHeroFaint => _palette.onHeroFaint;
  static Color get onHeroLine => _palette.onHeroLine;

  static Border get glassBorder => Border.all(color: line);

  /// Fill for cards, list entries and inputs.
  static LinearGradient get glassGradient => _palette.glassGradient;

  /// Stronger fill for balance and summary cards.
  static LinearGradient get heroGradient => _palette.heroGradient;

  /// Progress fill for budgets that are on track.
  static LinearGradient get onTrackGradient =>
      LinearGradient(colors: [lavender, mint]);
}

ThemeData buildArthamTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ArthamColors.lavender,
        brightness: ArthamColors.palette.brightness,
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
    splashFactory: InkRipple.splashFactory,
    brightness: ArthamColors.palette.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: ArthamColors.ink,
    canvasColor: ArthamColors.sheet,
    fontFamily: 'Roboto',
    dividerColor: ArthamColors.line,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ArthamColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ArthamColors.glass,
      labelStyle: TextStyle(color: ArthamColors.muted),
      hintStyle: TextStyle(color: ArthamColors.faint),
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
        side: BorderSide(color: ArthamColors.lavender),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ArthamColors.lavender),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ArthamColors.peach,
      foregroundColor: ArthamColors.onAccent,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      color: ArthamColors.glass,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ArthamColors.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ArthamColors.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: ArthamColors.line),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: ArthamColors.sheet,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: ArthamColors.sheet,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ArthamColors.text,
      contentTextStyle: TextStyle(
        color: ArthamColors.onAccent,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: ArthamColors.line),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: ArthamColors.lavender,
      linearTrackColor: ArthamColors.line,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: ArthamColors.muted,
      textColor: ArthamColors.text,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ArthamColors.glass,
      selectedColor: ArthamColors.lavenderTint,
      side: BorderSide(color: ArthamColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArthamColors.onAccent
            : (ArthamColors.isDark ? ArthamColors.text : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArthamColors.lavender
            : ArthamColors.line,
      ),
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

/// The app ground: deep purple with lavender, mint and peach glows.
class ArthamBackground extends StatelessWidget {
  const ArthamBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: ArthamColors.ink),
        for (final (center, radius, color) in ArthamColors.palette.glows)
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
    this.gradient,
    this.padding,
    this.blur = 24,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Gradient? gradient;
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
            gradient: gradient ?? ArthamColors.glassGradient,
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
                builder: (context, value, _) => AnimatedScale(
                  // The selected icon pops slightly as the capsule arrives.
                  scale: selected ? 1.14 : 1,
                  duration: ArthamTabBar.slideDuration,
                  curve: Curves.easeOutBack,
                  child: Icon(tab.icon, size: 22, color: value),
                ),
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
