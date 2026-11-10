import 'package:flutter/material.dart';

/// Pastel, calm Artham splash (~3.2 s): soft colour blobs drift in, a halo
/// opens, the lavender and mint strokes of the "A" draw, a rupee coin lands
/// and its ₹ is drawn on, then the wordmark rises. Call [onDone] to move on.
class ArthamSplashPastel extends StatefulWidget {
  const ArthamSplashPastel({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<ArthamSplashPastel> createState() => _State();
}

class _State extends State<ArthamSplashPastel>
    with SingleTickerProviderStateMixin {
  static const _ink = Color(0xFF3B2F63);
  static const _muted = Color(0xFF8B82AB);

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward().whenComplete(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (mounted) widget.onDone();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _p(double a, double b, [Curve k = Curves.linear]) =>
      k.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final word = _p(0.66, 0.9, Curves.easeOut);
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF1E6),
                  Color(0xFFEFE7FF),
                  Color(0xFFD9F3E8),
                ],
                stops: [0, .52, 1],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _Blobs(_p(0.03, 0.45, Curves.easeOut)),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 210,
                        height: 210,
                        child: CustomPaint(
                          painter: _Mark(
                            halo: _p(0.06, 0.34, Curves.easeOutCubic),
                            l1: _p(0.19, 0.43, Curves.easeInOutCubic),
                            l2: _p(0.27, 0.51, Curves.easeInOutCubic),
                            coin: _p(0.47, 0.76, Curves.easeOutBack),
                            rupee: _p(0.62, 0.82, Curves.easeOut),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Opacity(
                        opacity: word,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - word)),
                          child: Column(
                            children: const [
                              Text(
                                'ARTHAM',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 6,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'അർത്ഥം',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 48,
                  child: Opacity(
                    opacity: _p(0.8, 0.95),
                    child: const Text(
                      'MONEY, MADE MEANINGFUL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Blobs extends CustomPainter {
  _Blobs(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    void blob(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: .5 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }

    blob(Offset(20, 30), 100, const Color(0xFFFFD0B5));
    blob(
      Offset(s.width - 10, s.height * .66),
      120,
      const Color(0xFFC9B9FB),
    );
    blob(Offset(30, s.height - 10), 95, const Color(0xFFA6E8CF));
  }

  @override
  bool shouldRepaint(_Blobs o) => o.t != t;
}

class _Mark extends CustomPainter {
  _Mark({
    required this.halo,
    required this.l1,
    required this.l2,
    required this.coin,
    required this.rupee,
  });

  final double halo;
  final double l1;
  final double l2;
  final double coin;
  final double rupee;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 744);
    canvas.translate(-140, -150);

    if (halo > 0) {
      canvas.save();
      canvas.translate(512, 540);
      canvas.scale(.6 + .4 * halo);
      canvas.drawCircle(
        Offset.zero,
        372,
        Paint()..color = Colors.white.withValues(alpha: .55 * halo),
      );
      canvas.drawCircle(
        Offset.zero,
        372,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white.withValues(alpha: .8 * halo),
      );
      canvas.restore();
    }

    void leg(Offset from, Offset to, double t, List<Color> colors) {
      if (t <= 0) return;

      final end = Offset.lerp(from, to, t)!;
      final shadow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 96
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6A5AA8).withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

      canvas.drawLine(from.translate(0, 14), end.translate(0, 14), shadow);
      canvas.drawLine(
        from,
        end,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 96
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(const Rect.fromLTWH(298, 276, 428, 494)),
      );
    }

    leg(
      const Offset(298, 770),
      const Offset(512, 276),
      l1,
      const [Color(0xFFC9B9FB), Color(0xFFA995EE)],
    );
    leg(
      const Offset(726, 770),
      const Offset(512, 276),
      l2,
      const [Color(0xFFA6E8CF), Color(0xFF78D3B3)],
    );

    if (coin > 0) {
      final k = Curves.easeOut.transform(coin.clamp(0.0, 1.0));
      final c = Offset(512, 610 - 150 * (1 - coin));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(.8 + .2 * k);
      canvas.drawCircle(
        const Offset(0, 8),
        104,
        Paint()
          ..color = const Color(0xFFB5683A).withValues(alpha: .28 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(
        Offset.zero,
        104,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE7B8), Color(0xFFFFC79A)],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: 104),
          ),
      );
      canvas.drawCircle(
        Offset.zero,
        85,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = Colors.white.withValues(alpha: .75),
      );

      if (rupee > 0) {
        final r = Path()
          ..moveTo(-24, -32)
          ..lineTo(26, -32)
          ..moveTo(-24, -14)
          ..lineTo(26, -14)
          ..moveTo(-24, -32)
          ..lineTo(-2, -32)
          ..cubicTo(24, -32, 24, 6, -2, 6)
          ..lineTo(-24, 6)
          ..lineTo(20, 44);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF5D4A92);
        canvas.scale(1.08);
        for (final m in r.computeMetrics()) {
          canvas.drawPath(m.extractPath(0, m.length * rupee), paint);
        }
      }
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_Mark o) => true;
}
