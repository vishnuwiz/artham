// Artham getting started (onboarding) screen — v0.2 redesign.
//
// Visual language and copy follow the Artham website: deep navy-violet base,
// pastel lavender / mint / peach accents, glass cards, small eyebrow labels,
// and headlines whose second half is set in italic serif.
//
// Zero third-party dependencies. All micro-animations are native Flutter
// (AnimationController + CustomPainter), so no asset files are required.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class AC {
  static const bg = Color(0xFF17132A); // matches the website theme colour
  static const text = Color(0xFFF4F1FF);
  static const textSoft = Color(0xFFA9A3C7);
  static const lavender = Color(0xFFB8A9FF);
  static const mint = Color(0xFF9FE8CB);
  static const peach = Color(0xFFFFC7A0);
}

Color alpha(Color c, double o) =>
    c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

/// Maps [t] in [a, b] to 0..1 and applies [curve]. Used to stagger animations
/// inside one controller.
double iv(double t, double a, double b, [Curve curve = Curves.easeOutCubic]) =>
    curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0).toDouble());

/// Indian digit grouping: 1284 -> 1,284 ; 124580 -> 1,24,580
String inr(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

// ─────────────────────────────────────────────────────────────────────────────
// Getting started screen
// ─────────────────────────────────────────────────────────────────────────────
class GettingStartedScreen extends StatefulWidget {
  const GettingStartedScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  State<GettingStartedScreen> createState() => _GettingStartedScreenState();
}

class _GettingStartedScreenState extends State<GettingStartedScreen>
    with SingleTickerProviderStateMixin {
  static const _count = 5;

  final PageController _pc = PageController();
  final ValueNotifier<double> _page = ValueNotifier<double>(0);
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() {
      if (_pc.hasClients) _page.value = _pc.page ?? 0;
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    _page.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_index < _count - 1) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onGetStarted();
    }
  }

  void _skip() {
    HapticFeedback.selectionClick();
    _pc.animateToPage(
      _count - 1,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      OnboardPageShell(
        index: 0,
        page: _page,
        eyebrow: 'Money should mean something',
        titleTop: 'Your money,',
        titleAccent: 'under control.',
        subtitle: 'Artham shows every account as one balance and keeps your spending inside the limits you set.',
        hero: (t) => _WelcomeHero(t: t, loop: _loop),
      ),
      OnboardPageShell(
        index: 1,
        page: _page,
        eyebrow: 'Home',
        titleTop: 'Every account,',
        titleAccent: 'one balance.',
        subtitle: 'See your total balance, this month’s income and expenses, and a card for each bank.',
        hero: (t) => _HomeHero(t: t, loop: _loop),
      ),
      OnboardPageShell(
        index: 2,
        page: _page,
        eyebrow: 'Activity',
        titleTop: 'Every rupee,',
        titleAccent: 'on record.',
        subtitle: 'Add transactions, search and filter them, or paste a bank alert and review it before saving.',
        hero: (t) => _ActivityHero(t: t, loop: _loop),
      ),
      OnboardPageShell(
        index: 3,
        page: _page,
        eyebrow: 'Budgets',
        titleTop: 'Stay inside',
        titleAccent: 'the line.',
        subtitle: 'Set a monthly budget and category limits. Artham alerts you at 80% and again at 100%.',
        hero: (t) => _BudgetsHero(t: t),
      ),
      OnboardPageShell(
        index: 4,
        page: _page,
        eyebrow: 'Insights',
        titleTop: 'See where',
        titleAccent: 'it goes.',
        subtitle: 'Net savings, savings rate, and six months of income versus expenses in one view.',
        hero: (t) => _InsightsHero(t: t),
        footer: const _LocalFirstNote(),
      ),
    ];

    return Scaffold(
      backgroundColor: AC.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AuroraBackground(loop: _loop, page: _page),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(showSkip: _index != _count - 1, onSkip: _skip),
                Expanded(
                  child: PageView(
                    controller: _pc,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                    },
                    children: pages,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      _PageIndicator(count: _count, page: _page),
                      const SizedBox(height: 22),
                      _PressableButton(
                        label: _index == _count - 1 ? 'Get started' : 'Next',
                        emphasis: _index == _count - 1,
                        loop: _loop,
                        onTap: _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar, indicator, CTA
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 12, 0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: AC.lavender,
            ),
            child: const Text(
              'A',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AC.bg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'ARTHAM',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 3,
              color: AC.text,
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: showSkip ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !showSkip,
              child: TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AC.textSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.page});

  final int count;
  final ValueListenable<double> page;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: page,
      builder: (context, p, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Builder(
                builder: (context) {
                  final a = (1 - (p - i).abs()).clamp(0.0, 1.0).toDouble();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8 + 22 * a,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Color.lerp(
                        alpha(Colors.white, .2),
                        AC.lavender,
                        a,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.label,
    required this.onTap,
    required this.loop,
    required this.emphasis,
  });

  final String label;
  final VoidCallback onTap;
  final Animation<double> loop;
  final bool emphasis;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: widget.loop,
          builder: (context, _) {
            final tau = math.pi * 2;
            final glow = widget.emphasis
                ? 24 + 14 * (math.sin(widget.loop.value * tau * 2) + 1) / 2
                : 0.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              height: 58,
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.emphasis ? AC.lavender : AC.text,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (widget.emphasis)
                    BoxShadow(
                      color: alpha(AC.lavender, .35),
                      blurRadius: glow,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .4),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      widget.label,
                      key: ValueKey(widget.label),
                      style: const TextStyle(
                        color: AC.bg,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Transform.translate(
                    offset: Offset(
                      3.5 * math.sin(widget.loop.value * tau * 4),
                      0,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AC.bg,
                      size: 22,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable building blocks
// ─────────────────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: alpha(Colors.white, .14), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [alpha(Colors.white, .10), alpha(Colors.white, .04)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Small rounded label that pops in with an elastic scale.
class _PopChip extends StatelessWidget {
  const _PopChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.t,
    required this.start,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double t;
  final double start;

  @override
  Widget build(BuildContext context) {
    final scale = iv(t, start, start + .28, Curves.elasticOut);
    final op = iv(t, start, start + .1, Curves.linear);
    return Opacity(
      opacity: op,
      child: Transform.scale(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AC.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: alpha(color, .7)),
            boxShadow: [
              BoxShadow(
                color: alpha(color, .25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plays its animation (0 -> 1) whenever its page becomes the current one and
/// resets once the page is fully off-screen, so every page "re-introduces"
/// itself each time the user lands on it.
class ReplayOnActive extends StatefulWidget {
  const ReplayOnActive({
    super.key,
    required this.index,
    required this.page,
    required this.duration,
    required this.builder,
  });

  final int index;
  final ValueListenable<double> page;
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<ReplayOnActive> createState() => _ReplayOnActiveState();
}

class _ReplayOnActiveState extends State<ReplayOnActive>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    widget.page.addListener(_onPage);
    _onPage();
  }

  void _onPage() {
    final d = (widget.page.value - widget.index).abs();
    if (d < 0.5) {
      if (!_played) {
        _played = true;
        _c.forward(from: 0);
      }
    } else if (d >= 1.0) {
      _played = false;
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    widget.page.removeListener(_onPage);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(context, _c.value),
    );
  }
}

class OnboardPageShell extends StatelessWidget {
  const OnboardPageShell({
    super.key,
    required this.index,
    required this.page,
    required this.eyebrow,
    required this.titleTop,
    required this.titleAccent,
    required this.subtitle,
    required this.hero,
    this.footer,
  });

  final int index;
  final ValueListenable<double> page;
  final String eyebrow;
  final String titleTop;
  final String titleAccent;
  final String subtitle;
  final Widget Function(double t) hero;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 32,
      height: 1.12,
      fontWeight: FontWeight.w700,
      color: AC.text,
      letterSpacing: -0.6,
    );
    return ReplayOnActive(
      index: index,
      page: page,
      duration: const Duration(milliseconds: 2600),
      builder: (context, t) {
        final ee = iv(t, .3, .55);
        final te = iv(t, .38, .7);
        final se = iv(t, .5, .85);
        final fe = iv(t, .65, .95);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: page,
                  child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: hero(t)),
                  ),
                  builder: (context, p, child) {
                    final d = index - p;
                    return Opacity(
                      opacity: (1 - d.abs()).clamp(0.0, 1.0).toDouble(),
                      child: Transform.translate(
                        offset: Offset(d * 90, 0),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
              Opacity(
                opacity: ee,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - ee)),
                  child: Text(
                    eyebrow.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                      color: AC.mint,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: te,
                child: Transform.translate(
                  offset: Offset(0, 22 * (1 - te)),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$titleTop\n', style: titleStyle),
                        TextSpan(
                          text: titleAccent,
                          style: titleStyle.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'serif',
                            fontFamilyFallback: const ['Georgia', 'serif'],
                            color: AC.lavender,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: se,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - se)),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.5,
                      color: AC.textSoft,
                    ),
                  ),
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 14),
                Opacity(opacity: fe, child: footer),
              ],
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }
}

class _LocalFirstNote extends StatelessWidget {
  const _LocalFirstNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.lock_outline_rounded, size: 16, color: AC.mint),
        SizedBox(width: 8),
        Text(
          'Your data stays on your phone.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AC.mint,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aurora background — soft pastel glows that drift and re-tint per page
// ─────────────────────────────────────────────────────────────────────────────
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.loop, required this.page});

  final Animation<double> loop;
  final ValueListenable<double> page;

  static const _sets = <List<Color>>[
    [AC.lavender, AC.mint, AC.peach],
    [AC.mint, AC.lavender, AC.peach],
    [AC.peach, AC.lavender, AC.mint],
    [AC.lavender, AC.peach, AC.mint],
    [AC.mint, AC.peach, AC.lavender],
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([loop, page]),
      builder: (context, _) {
        final p = page.value.clamp(0.0, _sets.length - 1.0).toDouble();
        final i = p.floor();
        final f = p - i;
        final j = math.min(i + 1, _sets.length - 1);
        Color c(int k) => Color.lerp(_sets[i][k], _sets[j][k], f)!;
        final l = loop.value * math.pi * 2;

        Widget blob(Alignment a, double size, Color color) => Align(
          alignment: a,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [alpha(color, .32), alpha(color, 0)],
              ),
            ),
          ),
        );

        return Container(
          color: AC.bg,
          child: Stack(
            children: [
              blob(
                Alignment(
                  -0.95 + 0.2 * math.sin(l) - p * 0.06,
                  -0.9 + 0.1 * math.cos(l),
                ),
                380,
                c(0),
              ),
              blob(
                Alignment(
                  1.0 - 0.2 * math.cos(l) + p * 0.04,
                  -0.1 + 0.15 * math.sin(l + 1),
                ),
                340,
                c(1),
              ),
              blob(
                Alignment(
                  -0.3 + 0.25 * math.sin(l + 2),
                  1.1 + 0.08 * math.cos(l),
                ),
                400,
                c(2),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 — Welcome: spinning coin, orbiting chips, ripples
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.t, required this.loop});

  final double t;
  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final tau = math.pi * 2;
        final l = loop.value;
        final enter = iv(t, 0, .7, Curves.easeOutBack);
        final spin = (1 - iv(t, 0, .85, Curves.easeOutCubic)) * tau;
        final angle = spin + math.sin(l * tau) * .4;
        final bob = math.sin(l * tau * 2) * 6;

        const chipIcons = [
          (Icons.eco_rounded, AC.mint),
          (Icons.trending_up_rounded, AC.lavender),
          (Icons.savings_rounded, AC.peach),
        ];

        Widget chip(int i) {
          final a = l * tau + i * tau / 3;
          final depth = math.sin(a);
          final s = enter * (.8 + .2 * (depth + 1) / 2);
          final (icon, color) = chipIcons[i];
          return Transform.translate(
            offset: Offset(math.cos(a) * 125, depth * 48 - 10),
            child: Transform.scale(
              scale: s,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alpha(Colors.white, .08),
                  border: Border.all(color: alpha(color, .75), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: alpha(color, .25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
          );
        }

        final order = [0, 1, 2];
        bool isBack(int i) => math.sin(l * tau + i * tau / 3) < 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 300,
              height: 290,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(300, 290),
                    painter: _RipplePainter(
                      l,
                      enter.clamp(0.0, 1.0).toDouble(),
                    ),
                  ),
                  for (final i in order)
                    if (isBack(i)) chip(i),
                  Transform.scale(
                    scale: enter,
                    child: Transform.translate(
                      offset: Offset(0, bob),
                      child: _Coin(angle: angle),
                    ),
                  ),
                  for (final i in order)
                    if (!isBack(i)) chip(i),
                ],
              ),
            ),
            Opacity(
              opacity: iv(t, .55, .9),
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - iv(t, .55, .9))),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: alpha(Colors.white, .08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: alpha(Colors.white, .16)),
                  ),
                  child: const Text(
                    'അർത്ഥം  ·  meaning',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AC.text,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.angle});

  final double angle;

  @override
  Widget build(BuildContext context) {
    final back = math.cos(angle) < 0;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0012)
        ..rotateY(angle),
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: alpha(Colors.white, .9), width: 4),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE3CF), AC.peach, Color(0xFFFFAE7C)],
          ),
          boxShadow: [
            BoxShadow(
              color: alpha(AC.peach, .35),
              blurRadius: 44,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: alpha(const Color(0xFFD9732F), .5),
                width: 2.5,
              ),
            ),
            child: Center(
              child: Transform(
                alignment: Alignment.center,
                // Keep the ₹ readable when the coin is facing away.
                transform: Matrix4.diagonal3Values(back ? -1.0 : 1.0, 1.0, 1.0),
                child: const Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD9732F),
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

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.l, this.enter);

  final double l;
  final double enter;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var k = 0; k < 3; k++) {
      final phase = (l * 2 + k / 3) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = alpha(AC.lavender, (1 - phase) * .4 * enter);
      canvas.drawCircle(c, 70 + 80 * phase, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.l != l || old.enter != enter;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — Home: one balance, bank cards fan out
// ─────────────────────────────────────────────────────────────────────────────
class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.t, required this.loop});

  final double t;
  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    const banks = [
      ('HDFC Bank', '··1024', AC.lavender, '₹62,300'),
      ('SBI', '··7781', AC.mint, '₹38,450'),
      ('Federal Bank', '··3302', AC.peach, '₹23,830'),
    ];
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total balance',
                  style: TextStyle(fontSize: 12.5, color: AC.textSoft),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${inr((124580 * iv(t, .1, .7)).round())}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AC.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Income',
                        value: '₹48,000',
                        color: AC.mint,
                        icon: Icons.south_west_rounded,
                        e: iv(t, .35, .6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        label: 'Expenses',
                        value: '₹21,350',
                        color: AC.peach,
                        icon: Icons.north_east_rounded,
                        e: iv(t, .45, .7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 112,
            child: AnimatedBuilder(
              animation: loop,
              builder: (context, _) {
                final spread = iv(t, .4, .95, Curves.easeOutBack);
                Widget card(int i) {
                  final enter = iv(t, .35 + i * .08, .7 + i * .08);
                  final bob = math.sin(loop.value * math.pi * 4 + i) * 3;
                  final (name, last4, color, bal) = banks[i];
                  return Opacity(
                    opacity: enter,
                    child: Transform.translate(
                      offset: Offset(
                        (i - 1) * 92.0 * spread,
                        bob + 24 * (1 - enter),
                      ),
                      child: Transform.rotate(
                        angle: (i - 1) * .12 * spread,
                        child: _BankCard(
                          name: name,
                          last4: last4,
                          color: color,
                          balance: bal,
                        ),
                      ),
                    ),
                  );
                }

                return Stack(
                  alignment: Alignment.center,
                  children: [card(0), card(2), card(1)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.e,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final double e;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: e,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - e)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: alpha(Colors.white, .06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alpha(color, .18),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11.5, color: AC.textSoft),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AC.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({
    required this.name,
    required this.last4,
    required this.color,
    required this.balance,
  });

  final String name;
  final String last4;
  final Color color;
  final String balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 88,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Color.lerp(AC.bg, color, .22),
        border: Border.all(color: alpha(color, .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AC.text,
                  ),
                ),
              ),
              Text(
                last4,
                style: const TextStyle(fontSize: 11.5, color: AC.textSoft),
              ),
            ],
          ),
          Text(
            balance,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 — Activity: typing search, cycling filters, staggered rows
// ─────────────────────────────────────────────────────────────────────────────
class _Tx {
  const _Tx(this.icon, this.color, this.title, this.sub, this.amount);

  final IconData icon;
  final Color color;
  final String title;
  final String sub;

  /// Whole rupees; negative = expense, positive = income.
  final int amount;
}

class _ActivityHero extends StatelessWidget {
  const _ActivityHero({required this.t, required this.loop});

  final double t;
  final Animation<double> loop;

  static const _filters = ['All', 'Expenses', 'Income'];
  static const _txs = <_Tx>[
    _Tx(Icons.ramen_dining_rounded, AC.peach, 'Swiggy', 'Food · 9:12 AM', -349),
    _Tx(
      Icons.account_balance_wallet_rounded,
      AC.lavender,
      'Salary',
      'Income · 1 Nov',
      48000,
    ),
    _Tx(
      Icons.directions_bus_rounded,
      AC.mint,
      'Kochi Metro',
      'Travel · 8:30 AM',
      -60,
    ),
    _Tx(Icons.undo_rounded, AC.mint, 'Refund', 'Income · Yesterday', 150),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: AnimatedBuilder(
          animation: loop,
          builder: (context, _) {
            // Starts on "All" while the rows slide in, then cycles the
            // filters. The list and the net total follow the active filter.
            final selected = t < .7 ? 0 : (loop.value * 3).floor() % 3;
            bool visible(_Tx x) =>
                selected == 0 ||
                (selected == 1 && x.amount < 0) ||
                (selected == 2 && x.amount > 0);
            final net = _txs
                .where(visible)
                .fold<int>(0, (sum, x) => sum + x.amount);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                GlassCard(
                  child: Column(
                    children: [
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: alpha(Colors.white, .07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AC.textSoft,
                            ),
                            SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Search transactions',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: AC.textSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < _filters.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: i == selected
                                      ? AC.lavender
                                      : alpha(Colors.white, .08),
                                ),
                                child: Text(
                                  _filters[i],
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: i == selected ? AC.bg : AC.textSoft,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (var i = 0; i < _txs.length; i++)
                        ClipRect(
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            heightFactor: visible(_txs[i]) ? 1.0 : 0.0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: visible(_txs[i]) ? 1.0 : 0.0,
                              child: _TxRow(
                                icon: _txs[i].icon,
                                color: _txs[i].color,
                                title: _txs[i].title,
                                sub: _txs[i].sub,
                                amount: _txs[i].amount < 0
                                    ? '−₹${inr(-_txs[i].amount)}'
                                    : '+₹${inr(_txs[i].amount)}',
                                amountColor: _txs[i].amount < 0
                                    ? AC.text
                                    : AC.mint,
                                t: t,
                                start: .24 + i * .1,
                              ),
                            ),
                          ),
                        ),
                      const Divider(height: 18, color: Color(0x1FFFFFFF)),
                      Opacity(
                        opacity: iv(t, .65, .85),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Net movement',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AC.textSoft,
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: net.toDouble(),
                              ),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) {
                                final n = v.round();
                                return Text(
                                  '${n < 0 ? '−' : '+'}₹${inr(n)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: n < 0 ? AC.peach : AC.mint,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -18,
                  right: 14,
                  child: _PopChip(
                    icon: Icons.content_paste_rounded,
                    label: 'Paste a bank alert',
                    color: AC.peach,
                    t: t,
                    start: .72,
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

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.amount,
    required this.amountColor,
    required this.t,
    required this.start,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final String amount;
  final Color amountColor;
  final double t;
  final double start;

  @override
  Widget build(BuildContext context) {
    final e = iv(t, start, start + .22);
    return Opacity(
      opacity: e,
      child: Transform.translate(
        offset: Offset(50 * (1 - e), 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: alpha(color, .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AC.text,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(fontSize: 12, color: AC.textSoft),
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 4 — Budgets: ring, limits with an 80% marker, alert chip
// ─────────────────────────────────────────────────────────────────────────────
class _BudgetsHero extends StatelessWidget {
  const _BudgetsHero({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final ring = iv(t, .05, .8, Curves.easeInOutCubic);
    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassCard(
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        color: AC.textSoft,
                        size: 24,
                      ),
                      Text(
                        'November',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AC.text,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AC.textSoft,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(130, 130),
                          painter: _RingPainter(progress: .72 * ring),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(72 * ring).round()}%',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: AC.text,
                              ),
                            ),
                            const Text(
                              'used',
                              style: TextStyle(
                                fontSize: 12,
                                color: AC.textSoft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '₹21,600 of ₹30,000',
                    style: TextStyle(fontSize: 12.5, color: AC.textSoft),
                  ),
                  const SizedBox(height: 14),
                  _BudgetBar(
                    label: 'Food',
                    value: .68,
                    e: iv(t, .30, .75),
                    base: AC.lavender,
                  ),
                  const SizedBox(height: 10),
                  _BudgetBar(
                    label: 'Travel',
                    value: .45,
                    e: iv(t, .40, .85),
                    base: AC.mint,
                  ),
                  const SizedBox(height: 10),
                  _BudgetBar(
                    label: 'Fun',
                    value: .85,
                    e: iv(t, .50, .95),
                    base: AC.lavender,
                  ),
                ],
              ),
            ),
            Positioned(
              top: -18,
              right: 14,
              child: _PopChip(
                icon: Icons.notifications_active_rounded,
                label: 'Fun passed 80%',
                color: AC.peach,
                t: t,
                start: .78,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.label,
    required this.value,
    required this.e,
    required this.base,
  });

  final String label;
  final double value;
  final double e;
  final Color base;

  @override
  Widget build(BuildContext context) {
    final v = (value * e).clamp(0.0, 1.0).toDouble();
    // Turns peach once it crosses the 80% alert line.
    final color = v > .8 ? AC.peach : base;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: AC.text,
              ),
            ),
            Text(
              '${(v * 100).round()}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 14,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: alpha(Colors.white, .09),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(.6, 0),
                child: Container(
                  width: 2,
                  height: 14,
                  color: alpha(Colors.white, .45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = alpha(Colors.white, .09),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 12
        ..shader = const SweepGradient(
          colors: [AC.lavender, AC.mint],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 5 — Insights: net savings + six-month income vs expenses bars
// ─────────────────────────────────────────────────────────────────────────────
class _InsightsHero extends StatelessWidget {
  const _InsightsHero({required this.t});

  final double t;

  static const _months = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'];
  static const _income = [42.0, 45.0, 44.0, 46.0, 47.0, 48.0];
  static const _expense = [30.0, 28.0, 35.0, 26.0, 31.0, 21.35];

  @override
  Widget build(BuildContext context) {
    const maxH = 96.0;
    const maxV = 50.0;
    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Net savings',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AC.textSoft,
                            ),
                          ),
                          Text(
                            '₹${inr((26650 * iv(t, .1, .7)).round())}',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AC.text,
                            ),
                          ),
                        ],
                      ),
                      Opacity(
                        opacity: iv(t, .4, .6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: alpha(AC.mint, .16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(56 * iv(t, .4, .9)).round()}% saved',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AC.mint,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: maxH + 22,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < _months.length; i++)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _Bar(
                                    h:
                                        maxH *
                                        _income[i] /
                                        maxV *
                                        iv(
                                          t,
                                          .15 + i * .06,
                                          .6 + i * .06,
                                          Curves.easeOutBack,
                                        ),
                                    color: AC.lavender,
                                  ),
                                  const SizedBox(width: 3),
                                  _Bar(
                                    h:
                                        maxH *
                                        _expense[i] /
                                        maxV *
                                        iv(
                                          t,
                                          .2 + i * .06,
                                          .65 + i * .06,
                                          Curves.easeOutBack,
                                        ),
                                    color: AC.peach,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _months[i],
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AC.textSoft,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      _LegendDot(color: AC.lavender, label: 'Income'),
                      SizedBox(width: 16),
                      _LegendDot(color: AC.peach, label: 'Expenses'),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: -18,
              right: 14,
              child: _PopChip(
                icon: Icons.trending_up_rounded,
                label: 'On track this month',
                color: AC.mint,
                t: t,
                start: .8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.h, required this.color});

  final double h;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: math.max(0.0, h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AC.textSoft)),
      ],
    );
  }
}
