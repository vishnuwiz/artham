import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/artham_theme.dart';

/// Small, dependency-free interaction helpers shared across screens. Every
/// effect here is skipped when the system "reduce motion" setting is on.

/// Shrinks its child slightly while a finger is down and springs back on
/// release. Only pointer events are observed, so buttons inside [child] keep
/// working. When [onTap] is given the whole area is tappable and a light
/// haptic fires.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    Widget content = AnimatedScale(
      scale: _pressed && !reduce ? widget.scale : 1,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 140),
      curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    );
    if (widget.onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap!();
        },
        child: content,
      );
    }
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: content,
    );
  }
}

/// Sweeps a soft highlight across [child]. Wrap placeholder boxes in it.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
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
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              Color(0x00FFFFFF),
              Color(0x30FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradient(-1 + 2 * _controller.value),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}

/// A rounded placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Glass-card placeholders shown while a screen loads, in place of a spinner.
class SkeletonCards extends StatelessWidget {
  const SkeletonCards({super.key, this.count = 3, this.height = 120});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Shimmer(
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                height: height,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: ArthamColors.glassGradient,
                  border: ArthamColors.glassBorder,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 110, height: 12),
                    SizedBox(height: 14),
                    SkeletonBox(width: 190, height: 22, radius: 10),
                    Spacer(),
                    SkeletonBox(height: 8, radius: 8),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two side-by-side card placeholders, matching the Home account cards.
class SkeletonAccountRow extends StatelessWidget {
  const SkeletonAccountRow({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card() => Expanded(
      child: Container(
        height: 124,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: ArthamColors.glassGradient,
          border: ArthamColors.glassBorder,
          borderRadius: BorderRadius.circular(21),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 24, height: 24, radius: 8),
            SizedBox(height: 13),
            SkeletonBox(width: 80, height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 50, height: 10),
            Spacer(),
            SkeletonBox(width: 90, height: 16),
          ],
        ),
      ),
    );

    return Semantics(
      label: 'Loading accounts',
      child: Shimmer(
        child: Row(children: [card(), const SizedBox(width: 12), card()]),
      ),
    );
  }
}

/// A pill-shaped segmented control whose highlight glides (with a small
/// overshoot) from one option to the next instead of each option toggling on
/// its own.
class SlidingSegmented extends StatelessWidget {
  const SlidingSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.accent = ArthamColors.lavender,
    this.segmentWidth = 84,
    this.height = 40,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color accent;
  final double segmentWidth;
  final double height;

  static const Duration slideDuration = Duration(milliseconds: 380);

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final duration = reduce ? Duration.zero : slideDuration;
    const pad = 3.0;
    final radius = BorderRadius.circular(height);

    return Container(
      width: segmentWidth * labels.length + pad * 2,
      height: height,
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: ArthamColors.glass,
        borderRadius: radius,
        border: Border.all(color: ArthamColors.line),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: duration,
            curve: Curves.easeOutBack,
            left: selectedIndex * segmentWidth,
            top: 0,
            bottom: 0,
            width: segmentWidth,
            child: DecoratedBox(
              key: const ValueKey('sliding-segmented-pill'),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: radius,
                border: Border.all(color: accent.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                SizedBox(
                  width: segmentWidth,
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          style: TextStyle(
                            color: i == selectedIndex
                                ? accent
                                : ArthamColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows a full-screen "saved" confirmation (a circle that pops in, a tick
/// that draws itself and a ring that pulses outward) for a moment, then closes
/// it. Skipped when the system "reduce motion" setting is on.
Future<void> showSavedCheck(BuildContext context) async {
  if (MediaQuery.of(context).disableAnimations) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  HapticFeedback.mediumImpact();
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) =>
        const SuccessCheckOverlay(),
  );
  await Future<void>.delayed(const Duration(milliseconds: 950));
  if (navigator.mounted) navigator.pop();
}

class SuccessCheckOverlay extends StatefulWidget {
  const SuccessCheckOverlay({super.key});

  @override
  State<SuccessCheckOverlay> createState() => _SuccessCheckOverlayState();
}

class _SuccessCheckOverlayState extends State<SuccessCheckOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

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
        final t = _controller.value;
        final scrim = Curves.easeOut.transform((t / 0.25).clamp(0.0, 1.0));
        final pop = Curves.easeOutBack.transform((t / 0.4).clamp(0.0, 1.0));
        final tick = Curves.easeInOut.transform(
          ((t - 0.3) / 0.4).clamp(0.0, 1.0),
        );
        final pulse = ((t - 0.35) / 0.6).clamp(0.0, 1.0);
        final fadeOut = 1 - ((t - 0.85) / 0.15).clamp(0.0, 1.0);

        return Opacity(
          opacity: fadeOut,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.45 * scrim),
            child: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: _CheckPainter(pop: pop, tick: tick, pulse: pulse),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.pop, required this.tick, required this.pulse});

  final double pop;
  final double tick;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 46.0;

    if (pulse > 0 && pulse < 1) {
      canvas.drawCircle(
        center,
        radius * (1 + pulse * 0.9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ArthamColors.mint.withValues(alpha: 0.7 * (1 - pulse)),
      );
    }

    final circleRadius = radius * pop.clamp(0.0, 1.2);
    if (circleRadius > 0) {
      canvas.drawCircle(
        center,
        circleRadius,
        Paint()
          ..shader = const LinearGradient(
            colors: [ArthamColors.mint, Color(0xFF68DFB4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    if (tick > 0) {
      final path = Path()
        ..moveTo(center.dx - 18, center.dy + 1)
        ..lineTo(center.dx - 5, center.dy + 14)
        ..lineTo(center.dx + 20, center.dy - 13);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * tick),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF12301F),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.pop != pop || old.tick != tick || old.pulse != pulse;
}
