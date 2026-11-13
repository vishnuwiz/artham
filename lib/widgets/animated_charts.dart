import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/artham_theme.dart';

/// Shared, dependency-free animated chart widgets used by Home, Insights and
/// Budgets. Everything here animates from zero on first build and glides to the
/// new value when the data changes, and respects the system "reduce motion"
/// setting.

Duration _motion(BuildContext context, Duration duration) {
  return MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
}

/// Slice colours for pie charts, ordered so neighbouring slices contrast.
abstract final class ArthamChartPalette {
  static const List<Color> slices = [
    ArthamColors.lavender,
    ArthamColors.mint,
    ArthamColors.peach,
    Color(0xFF8CBEFF),
    Color(0xFFF2A7D8),
    Color(0xFFE6E89A),
    ArthamColors.debit,
  ];

  /// Colour used for the combined "Other" slice.
  static const Color other = ArthamColors.faint;

  static Color at(int index) => slices[index % slices.length];
}

/// A rounded progress bar whose fill grows with an eased animation.
///
/// [delay] staggers a list of bars so they ripple in one after another.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color = ArthamColors.lavender,
    this.endColor,
    this.trackColor = ArthamColors.line,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
    this.glow = true,
    this.pulse = false,
    this.shake = false,
    this.pulseColor = ArthamColors.peach,
  });

  /// Fraction filled, 0..1 (values outside the range are clamped).
  final double value;
  final double height;

  /// Fill colour. When [endColor] is set the fill is a left-to-right gradient.
  final Color color;
  final Color? endColor;
  final Color trackColor;
  final Duration delay;
  final Duration duration;

  /// Draws a soft glow under the fill.
  final bool glow;

  /// Once the fill has finished growing, glows in [pulseColor] a single time.
  /// Use for budgets at or near their limit.
  final bool pulse;

  /// Also gives the bar a short horizontal shake after it fills. Use for
  /// budgets that are over their limit.
  final bool shake;
  final Color pulseColor;

  @override
  Widget build(BuildContext context) {
    final bar = _buildBar(context);
    if (!pulse && !shake) return bar;
    final base = _motion(context, duration);
    if (base == Duration.zero) return bar;

    const effect = Duration(milliseconds: 1000);
    final total = base + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total + effect,
      curve: Interval(
        total.inMilliseconds / (total + effect).inMilliseconds,
        1,
        curve: Curves.easeInOut,
      ),
      child: bar,
      builder: (context, t, child) {
        final glowAmount = pulse ? math.sin(math.pi * t) : 0.0;
        final dx = shake ? math.sin(t * math.pi * 6) * (1 - t) * 3 : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              boxShadow: [
                BoxShadow(
                  color: pulseColor.withValues(alpha: 0.6 * glowAmount),
                  blurRadius: 14 * glowAmount,
                  spreadRadius: 1.5 * glowAmount,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildBar(BuildContext context) {
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final base = _motion(context, duration);
    final wait = base == Duration.zero ? Duration.zero : delay;
    final total = base + wait;
    final curve = total == Duration.zero
        ? Curves.linear
        : Interval(
            wait.inMilliseconds / total.inMilliseconds,
            1,
            curve: Curves.easeOutCubic,
          );
    final radius = BorderRadius.circular(height);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: total,
      curve: curve,
      builder: (context, v, _) {
        return Container(
          height: height,
          decoration: BoxDecoration(color: trackColor, borderRadius: radius),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fill = constraints.maxWidth * v;
              // Keep a tiny sliver visible so a non-zero value never vanishes
              // while the bar is still growing.
              final width = v <= 0 ? 0.0 : math.max(fill, height);
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: math.min(width, constraints.maxWidth),
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      colors: [color, endColor ?? color],
                    ),
                    boxShadow: glow && v > 0
                        ? [
                            BoxShadow(
                              color: (endColor ?? color).withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Counts a rupee amount up (or down) to [paise] with an ease-out curve.
///
/// Formatting matches the rest of the app: `₹1234.50`.
class AnimatedAmountText extends StatelessWidget {
  const AnimatedAmountText({
    super.key,
    required this.paise,
    this.style,
    this.duration = const Duration(milliseconds: 1100),
    this.prefix = '',
    this.maxLines,
    this.overflow,
  });

  final int paise;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: paise.toDouble()),
      duration: _motion(context, duration),
      curve: Curves.easeOutExpo,
      builder: (context, v, _) {
        return Text(
          '$prefix₹${(v / 100).toStringAsFixed(2)}',
          style: style,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

/// Counts a percentage label up, e.g. `42.5% used`.
class AnimatedPercentText extends StatelessWidget {
  const AnimatedPercentText({
    super.key,
    required this.fraction,
    this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  /// 0..n where 1 means 100 %.
  final double fraction;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: fraction.isNaN ? 0 : fraction),
      duration: _motion(context, duration),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text('${(v * 100).toStringAsFixed(1)}%$suffix', style: style);
      },
    );
  }
}

/// A vertical bar that grows up from the baseline. Stagger with [delay].
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    super.key,
    required this.height,
    required this.color,
    this.width = 9,
    this.minHeight = 2,
    this.maxHeight = 105,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 800),
  });

  final double height;
  final Color color;
  final double width;
  final double minHeight;
  final double maxHeight;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = (height.isNaN ? 0.0 : height)
        .clamp(minHeight, maxHeight)
        .toDouble();
    final base = _motion(context, duration);
    final wait = base == Duration.zero ? Duration.zero : delay;
    final total = base + wait;
    final curve = total == Duration.zero
        ? Curves.linear
        : Interval(
            wait.inMilliseconds / total.inMilliseconds,
            1,
            curve: Curves.easeOutBack,
          );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: total,
      curve: curve,
      builder: (context, v, _) {
        return Container(
          width: width,
          height: math.max(v, 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(width / 2),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0.55)],
            ),
          ),
        );
      },
    );
  }
}

/// One slice of an [AnimatedDonutChart].
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;

  /// Any positive number (the chart works out the proportions).
  final double value;
  final Color color;
}

/// An animated donut ("pie") chart.
///
/// The ring sweeps open on first build, and tapping a slice (or its legend
/// row) pops it out and shows its amount and share in the centre.
class AnimatedDonutChart extends StatefulWidget {
  const AnimatedDonutChart({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.formatValue,
    this.size = 190,
    this.strokeWidth = 26,
    this.showLegend = true,
  });

  final List<DonutSlice> slices;

  /// Small caption in the centre while nothing is selected, e.g. `SPENT`.
  final String centerLabel;

  /// Formats a slice value for display (the centre and the legend).
  final String Function(double value) formatValue;
  final double size;
  final double strokeWidth;
  final bool showLegend;

  @override
  State<AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<AnimatedDonutChart>
    with TickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _select = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  int? _selected;
  int? _previous;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.of(context).disableAnimations) {
        _sweep.value = 1;
      } else {
        _sweep.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.slices.length) {
      _selected = null;
      _previous = null;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _select.dispose();
    super.dispose();
  }

  double get _total =>
      widget.slices.fold<double>(0, (sum, item) => sum + item.value);

  void _choose(int? index) {
    if (index == _selected) index = null; // tap again to clear
    setState(() {
      _previous = _selected;
      _selected = index;
    });
    _select.forward(from: 0);
  }

  void _onTap(Offset local) {
    final total = _total;
    if (total <= 0) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = local - center;
    final distance = delta.distance;
    final outer = widget.size / 2;
    final inner = outer - widget.strokeWidth - 8;
    if (distance < inner || distance > outer + 6) {
      if (_selected != null) _choose(null);
      return;
    }
    // Angle measured clockwise from 12 o'clock, 0..2π.
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    var start = 0.0;
    for (var i = 0; i < widget.slices.length; i++) {
      final span = widget.slices[i].value / total * 2 * math.pi;
      if (angle >= start && angle < start + span) {
        _choose(i);
        return;
      }
      start += span;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final selected = _selected;
    return Column(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _onTap(details.localPosition),
            child: AnimatedBuilder(
              animation: Listenable.merge([_sweep, _select]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _DonutPainter(
                    slices: widget.slices,
                    total: total,
                    progress: Curves.easeOutCubic.transform(_sweep.value),
                    strokeWidth: widget.strokeWidth,
                    selected: _selected,
                    previous: _previous,
                    selectT: Curves.easeOutBack
                        .transform(_select.value)
                        .clamp(0.0, 1.2),
                  ),
                  child: Center(child: _centre(selected, total)),
                );
              },
            ),
          ),
        ),
        if (widget.showLegend) ...[
          const SizedBox(height: 18),
          for (var i = 0; i < widget.slices.length; i++)
            _legendRow(i, total),
        ],
      ],
    );
  }

  Widget _centre(int? selected, double total) {
    final inner = widget.size - widget.strokeWidth * 2 - 16;
    final slice = selected == null ? null : widget.slices[selected];
    final title = slice?.label ?? widget.centerLabel;
    final amount = widget.formatValue(slice?.value ?? total);
    final share = slice == null || total <= 0
        ? null
        : '${(slice.value / total * 100).toStringAsFixed(1)}%';
    return SizedBox(
      width: inner,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Column(
          key: ValueKey(selected),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: slice?.color ?? ArthamColors.muted,
                fontSize: 9,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount,
                style: const TextStyle(
                  color: ArthamColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (share != null) ...[
              const SizedBox(height: 2),
              Text(
                share,
                style: const TextStyle(
                  color: ArthamColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legendRow(int index, double total) {
    final slice = widget.slices[index];
    final share = total <= 0 ? 0.0 : slice.value / total;
    final active = _selected == index;
    final dimmed = _selected != null && !active;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _choose(index),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.45 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 13 : 10,
                height: active ? 13 : 10,
                decoration: BoxDecoration(
                  color: slice.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  slice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ArthamColors.text,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                widget.formatValue(slice.value),
                style: const TextStyle(
                  color: ArthamColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${(share * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.progress,
    required this.strokeWidth,
    required this.selected,
    required this.previous,
    required this.selectT,
  });

  final List<DonutSlice> slices;
  final double total;
  final double progress;
  final double strokeWidth;
  final int? selected;
  final int? previous;
  final double selectT;

  @override
  void paint(Canvas canvas, Size size) {
    const extra = 7.0;
    final radius = (size.shortestSide - strokeWidth - extra * 2) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track ring behind the slices.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = ArthamColors.glassSoft,
    );
    if (total <= 0) return;

    final gap = slices.length > 1 ? 0.045 : 0.0; // radians between slices
    final revealed = progress * 2 * math.pi;
    var start = -math.pi / 2;
    var consumed = 0.0;

    for (var i = 0; i < slices.length; i++) {
      final span = slices[i].value / total * 2 * math.pi;
      final visible = (revealed - consumed).clamp(0.0, span).toDouble();
      consumed += span;
      final drawn = visible - gap;
      if (drawn > 0) {
        var grow = 0.0;
        if (i == selected) grow = selectT;
        if (i == previous && i != selected) grow = 1 - selectT.clamp(0.0, 1.0);
        final width = strokeWidth + extra * grow;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = slices[i].color;
        // Rounded caps eat into the gap, so pull the ends in by half a stroke.
        final inset = gap > 0 ? width / 2 / radius * 0.5 : 0.0;
        final sweep = math.max(drawn - inset * 2, 0.001);
        canvas.drawArc(rect, start + gap / 2 + inset, sweep, false, paint);
      }
      start += span;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.progress != progress ||
        old.selected != selected ||
        old.previous != previous ||
        old.selectT != selectT ||
        old.total != total ||
        old.slices != slices ||
        old.strokeWidth != strokeWidth;
  }
}

/// A ring that sweeps to [value] (0..1) with a lavender-to-mint gradient,
/// counts the percentage up in its centre and glows once as it lands.
class AnimatedRing extends StatelessWidget {
  const AnimatedRing({
    super.key,
    required this.value,
    this.size = 88,
    this.strokeWidth = 9,
    this.caption = 'SAVED',
    this.duration = const Duration(milliseconds: 1500),
  });

  final double value;
  final double size;
  final double strokeWidth;
  final String caption;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final sweep = _motion(context, duration);
    const glowTime = Duration(milliseconds: 900);

    return Semantics(
      label: '$caption ${(target * 100).round()} percent',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: sweep,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: sweep == Duration.zero ? Duration.zero : sweep + glowTime,
              curve: sweep == Duration.zero
                  ? Curves.linear
                  : Interval(
                      sweep.inMilliseconds /
                          (sweep + glowTime).inMilliseconds,
                      1,
                      curve: Curves.easeInOut,
                    ),
              builder: (context, g, _) {
                return CustomPaint(
                  painter: _RingPainter(
                    progress: v,
                    glow: sweep == Duration.zero ? 0 : math.sin(math.pi * g),
                    strokeWidth: strokeWidth,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(v * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          caption,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.glow,
    required this.strokeWidth,
  });

  final double progress;
  final double glow;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white24,
    );
    if (progress <= 0) return;

    final sweep = progress * 2 * math.pi;
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: math.max(sweep, 0.01),
      colors: const [ArthamColors.lavender, ArthamColors.mint],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    if (glow > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 2
          ..strokeCap = StrokeCap.round
          ..shader = shader
          ..color = Colors.white.withValues(alpha: glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * glow),
      );
    }
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.glow != glow ||
      old.strokeWidth != strokeWidth;
}
