import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/artham_logo.dart';

const Color _night = Color(0xFF080C16);
const Color _indigo = Color(0xFF28204E);
const Color _teal = Color(0xFF20D9BD);
const Color _pink = Color(0xFFEA55B1);
const Color _gold = Color(0xFFF0B65E);

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onFinished();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _night,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: _night,
      ),
      child: Scaffold(
        backgroundColor: _night,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _AuroraBackground(),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ArthamLogoMark(
                            key: ValueKey('artham-splash-logo'),
                            size: 178,
                          ),
                          const SizedBox(height: 38),
                          const Text(
                            'ARTHAM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFF6F5FF),
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 7.2,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'അർഥം',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFC8CBE5),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Your Personal Finance Companion',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB0B4D0),
                              fontSize: 13,
                              letterSpacing: 0.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Container(
                            width: 54,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: const LinearGradient(
                                colors: [_teal, Color(0xFF8D83E8), _pink],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _teal.withValues(alpha: 0.32),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: Text(
                'PRIVATE BY DESIGN  •  YOUR DATA STAYS ON YOUR DEVICE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF777C9B),
                  fontSize: 8,
                  letterSpacing: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_indigo, Color(0xFF11182A), _night],
              stops: [0, 0.46, 1],
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -115,
          child: _glow(const Color(0xFFB63F9C), 360),
        ),
        Positioned(
          left: -175,
          top: 250,
          child: _glow(_teal, 390),
        ),
        Positioned(
          right: -175,
          bottom: 55,
          child: _glow(_gold, 355),
        ),
        Positioned(
          left: -120,
          bottom: -245,
          child: _glow(const Color(0xFF146E89), 410),
        ),
        const CustomPaint(painter: _GlassWavePainter()),
      ],
    );
  }

  Widget _glow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.34),
              color.withValues(alpha: 0.13),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}


class _GlassWavePainter extends CustomPainter {
  const _GlassWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.76)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.68,
        size.width * 0.46,
        size.height * 0.87,
        size.width * 0.68,
        size.height * 0.79,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.74,
        size.width * 0.92,
        size.height * 0.72,
        size.width,
        size.height * 0.75,
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        colors: [
          Color(0x664BE8D5),
          Color(0x33D8DDFB),
          Color(0x559D7EE8),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);

    final second = Path()
      ..moveTo(0, size.height * 0.81)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.73,
        size.width * 0.51,
        size.height * 0.91,
        size.width * 0.73,
        size.height * 0.84,
      )
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.80,
        size.width * 0.94,
        size.height * 0.78,
        size.width,
        size.height * 0.80,
      );
    canvas.drawPath(
      second,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x22C9D3FA),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
