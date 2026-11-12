// Artham animated splash screen (pastel A + rupee coin + BETA ribbon).
// Pure Flutter: no extra packages, no Lottie. Drop into lib/splash/.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

const _ink = Color(0xFF3B2F63);
const _muted = Color(0xFF8B82AB);
const _lav = Color(0xFFB6A4F5);
const _mint = Color(0xFF86DCBD);
const _peach = Color(0xFFFFD0B5);

/// Colour from 0xRRGGBB + alpha (works on every Flutter version).
Color _c(int rgb, [double a = 1]) => Color.fromRGBO(
  (rgb >> 16) & 255,
  (rgb >> 8) & 255,
  rgb & 255,
  a.clamp(0.0, 1.0),
);

/// Wrap your home screen with this. The splash plays once per cold start,
/// then cross-fades into [child].
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _showSplash
          ? ArthamSplash(
              key: const ValueKey('artham-splash'),
              onFinished: () {
                if (mounted) {
                  setState(() => _showSplash = false);
                }
              },
            )
          : KeyedSubtree(
              key: const ValueKey('artham-app'),
              child: widget.child,
            ),
    );
  }
}

class ArthamSplash extends StatefulWidget {
  const ArthamSplash({
    super.key,
    required this.onFinished,
    this.holdAfter = const Duration(milliseconds: 700),
  });

  /// Called once the animation has finished and [holdAfter] has passed.
  final VoidCallback onFinished;
  final Duration holdAfter;

  @override
  State<ArthamSplash> createState() => _ArthamSplashState();
}

class _ArthamSplashState extends State<ArthamSplash>
    with TickerProviderStateMixin {
  static const double _total = 3.6; // seconds

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  bool _started = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } // reduced motion
    _c.forward().whenComplete(() async {
      await Future<void>.delayed(widget.holdAfter);
      if (mounted && !_done) {
        _done = true;
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _pulse.dispose();
    super.dispose();
  }

  static double seg(
    double t,
    double start,
    double dur, [
    Curve curve = Curves.linear,
  ]) {
    final v = ((t - start) / dur).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final f = size.width / 320; // blob scale vs. the 320px design width
    final logoSize = (size.width * 0.58).clamp(200.0, 280.0);

    return Scaffold(
      backgroundColor: const Color(0xFFEFE7FF),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * _total;

          Widget blob(
            double start,
            Color color,
            double d, {
            double? top,
            double? bottom,
            double? left,
            double? right,
          }) {
            final o = 0.55 * seg(t, start, 1.4, Curves.easeOut);
            return Positioned(
              top: top,
              bottom: bottom,
              left: left,
              right: right,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 30,
                  sigmaY: 30,
                  tileMode: TileMode.decal,
                ),
                child: Container(
                  width: d * f,
                  height: d * f,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha((o * 255).round()),
                  ),
                ),
              ),
            );
          }

          final wp = seg(t, 2.2, 0.8, Curves.easeOut);
          final tagp = seg(t, 2.6, 0.8, Curves.easeOut);
          final dotsp = seg(t, 2.6, 0.5);

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.35, -1),
                    end: Alignment(0.35, 1),
                    colors: [
                      Color(0xFFFFF1E6),
                      Color(0xFFEFE7FF),
                      Color(0xFFD9F3E8),
                    ],
                    stops: [0, 0.52, 1],
                  ),
                ),
              ),
              blob(0.1, _peach, 200, top: -40 * f, left: -60 * f),
              blob(
                0.3,
                const Color(0xFFC9B9FB),
                240,
                bottom: 60 * f,
                right: -90 * f,
              ),
              blob(
                0.5,
                const Color(0xFFA6E8CF),
                180,
                bottom: -50 * f,
                left: -40 * f,
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: Semantics(
                          label: 'Artham logo, beta',
                          child: CustomPaint(painter: _LogoPainter(t)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Opacity(
                        opacity: wp,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - wp)),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 6,
                                ), // balance letter-spacing
                                child: Text(
                                  'ARTHAM',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'അർത്ഥം',
                                style: TextStyle(color: _muted, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 46 + bottomInset,
                child: Opacity(
                  opacity: tagp,
                  child: const Text(
                    'MONEY, MADE MEANINGFUL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 26 + bottomInset,
                child: Opacity(
                  opacity: dotsp,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(_lav, 0.0),
                        _dot(_peach, 0.14),
                        _dot(_mint, 0.27),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dot(Color color, double phase) {
    final v = (_pulse.value + phase) % 1.0;
    final k = v < 0.5 ? v * 2 : (1 - v) * 2; // 0..1..0
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.5),
      child: Opacity(
        opacity: 0.5 + 0.5 * k,
        child: Transform.scale(
          scale: 1 + 0.5 * k,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// Draws the logo in the original 744x744 design space (viewBox 140 150 744 744).
class _LogoPainter extends CustomPainter {
  _LogoPainter(this.t);
  final double t; // seconds into the animation

  static double _seg(double t, double s, double d, [Curve c = Curves.linear]) =>
      _ArthamSplashState.seg(t, s, d, c);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 744);
    canvas.translate(-140, -150);
    _halo(canvas);
    _lines(canvas);
    _coin(canvas);
    _sparks(canvas);
    _ribbon(canvas);
    canvas.restore();
  }

  void _halo(Canvas canvas) {
    final h = _seg(t, 0.2, 0.9, const Cubic(0.2, 0.9, 0.3, 1));
    if (h <= 0) {
      return;
    }
    canvas.save();
    canvas.translate(512, 540);
    canvas.scale(0.6 + 0.4 * h);
    canvas.translate(-512, -540);
    canvas.drawCircle(
      const Offset(512, 540),
      372,
      Paint()..color = _c(0xFFFFFF, 0.55 * h),
    );
    canvas.drawCircle(
      const Offset(512, 540),
      372,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _c(0xFFFFFF, 0.8 * h),
    );
    canvas.restore();
  }

  void _lines(Canvas canvas) {
    final p1 = _seg(t, 0.6, 0.75, const Cubic(0.6, 0, 0.3, 1));
    final p2 = _seg(t, 0.85, 0.75, const Cubic(0.6, 0, 0.3, 1));
    const a1 = Offset(298, 770), a2 = Offset(726, 770), apex = Offset(512, 276);

    Paint stroke(List<Color> colors, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 96
      ..shader = ui.Gradient.linear(
        const Offset(0, 276),
        const Offset(0, 770),
        colors,
      )
      ..color = _c(0xFFFFFF, alpha);

    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 96
      ..color = _c(0x6A5AA8, 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    const dy = Offset(0, 14);
    if (p1 > 0) {
      canvas.drawLine(a1 + dy, Offset.lerp(a1, apex, p1)! + dy, shadow);
    }
    if (p2 > 0) {
      canvas.drawLine(a2 + dy, Offset.lerp(a2, apex, p2)! + dy, shadow);
    }
    if (p1 > 0) {
      canvas.drawLine(
        a1,
        Offset.lerp(a1, apex, p1)!,
        stroke([_c(0xC9B9FB), _c(0xA995EE)], 1),
      );
    }
    if (p2 > 0) {
      canvas.drawLine(
        a2,
        Offset.lerp(a2, apex, p2)!,
        stroke([_c(0xA6E8CF), _c(0x78D3B3)], 0.92),
      );
    }
  }

  void _coin(Canvas canvas) {
    final land = _seg(t, 1.5, 0.9, const Cubic(0.3, 1.35, 0.5, 1));
    final op = _seg(t, 1.5, 0.315);
    if (op <= 0) {
      return;
    }

    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, op));
    canvas.translate(512, 610 - 150 * (1 - land));
    canvas.scale(0.8 + 0.2 * land);
    canvas.translate(-512, -610);

    const c = Offset(512, 610);
    canvas.drawCircle(
      c + const Offset(0, 8),
      104,
      Paint()
        ..color = _c(0xB5683A, 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      c,
      104,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(408, 506),
          const Offset(616, 714),
          [_c(0xFFE7B8), _c(0xFFC79A)],
        ),
    );
    canvas.drawCircle(
      c,
      85,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = _c(0xFFFFFF, 0.75),
    );

    final r = _seg(t, 2.0, 0.6, Curves.easeOut);
    if (r > 0) {
      canvas.save();
      canvas.translate(512, 610);
      canvas.scale(1.08);
      canvas.drawPath(
        _trim(_rupee(), r),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _c(0x5D4A92),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  Path _rupee() => Path()
    ..moveTo(-24, -32)
    ..lineTo(26, -32)
    ..moveTo(-24, -14)
    ..lineTo(26, -14)
    ..moveTo(-24, -32)
    ..lineTo(-2, -32)
    ..cubicTo(24, -32, 24, 6, -2, 6)
    ..lineTo(-24, 6)
    ..lineTo(20, 44);

  Path _trim(Path src, double f) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * f), Offset.zero);
    }
    return out;
  }

  void _sparks(Canvas canvas) {
    void spark(Offset c, double r, int rgb, double start) {
      final p = _seg(t, start, 1.2);
      if (p <= 0 || p >= 1) {
        return;
      }
      double op, sc, ty = 0;
      if (p < 0.4) {
        op = p / 0.4;
        sc = 0.2 + 0.8 * op;
      } else {
        final q = (p - 0.4) / 0.6;
        op = 1 - q;
        sc = 1 + 0.4 * q;
        ty = -8 * q;
      }
      canvas.drawCircle(
        c + Offset(0, ty),
        r * sc,
        Paint()..color = _c(rgb, op),
      );
    }

    spark(const Offset(660, 520), 12, 0xFFC79A, 2.2);
    spark(const Offset(372, 470), 9, 0xA995EE, 2.35);
    spark(const Offset(690, 650), 8, 0x78D3B3, 2.5);
  }

  void _ribbon(Canvas canvas) {
    final rp = _seg(t, 2.3, 0.7, const Cubic(0.2, 0.9, 0.3, 1));
    if (rp <= 0) {
      return;
    }

    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(512, 540), radius: 372)),
    );
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, rp));
    canvas.translate(
      60 * (1 - rp),
      -60 * (1 - rp),
    ); // slides in from the corner
    canvas.translate(713.5, 338.5);
    canvas.rotate(math.pi / 4);

    const band = Rect.fromLTWH(-360, -44, 720, 88);
    canvas.drawRect(
      band.shift(const Offset(0, 6)),
      Paint()
        ..color = _c(0x2E2254, 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawRect(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -44),
          const Offset(0, 44),
          [_c(0x7A63C4), _c(0x5D4A92)],
        ),
    );

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _c(0xFFFFFF, 0.45);
    for (final y in const [-34.0, 34.0]) {
      for (double x = -360; x < 360; x += 19) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 10, 360), y), dash);
      }
    }

    final tp = TextPainter(
      text: const TextSpan(
        text: 'BETA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 50,
          fontWeight: FontWeight.w700,
          letterSpacing: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(-(tp.width - 10) / 2, 17 - base));

    canvas.restore(); // layer
    canvas.restore(); // clip
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.t != t;
}
