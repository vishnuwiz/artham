import 'dart:ui';

import 'package:flutter/material.dart';

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
/// white capsule carrying its icon and label in dark ink.
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: GlassPanel(
        borderRadius: const BorderRadius.all(Radius.circular(33)),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            for (var index = 0; index < tabs.length; index++)
              Expanded(
                child: _TabButton(
                  tab: tabs[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
