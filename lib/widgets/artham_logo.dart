import 'package:flutter/material.dart';

const Color _brandTeal = Color(0xFF48E7D2);
const Color _brandViolet = Color(0xFF8F8CF2);

/// The circular glass medallion used throughout the Artham brand.
class ArthamLogoMark extends StatelessWidget {
  final double size;

  const ArthamLogoMark({super.key, this.size = 176});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        padding: EdgeInsets.all(size * 0.028),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brandTeal, Color(0xFF7F9BF4), _brandViolet],
          ),
          boxShadow: [
            BoxShadow(
              color: _brandTeal.withValues(alpha: 0.19),
              blurRadius: size * 0.24,
              spreadRadius: size * 0.012,
            ),
            BoxShadow(
              color: _brandViolet.withValues(alpha: 0.18),
              blurRadius: size * 0.19,
              spreadRadius: size * 0.02,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.25, -0.4),
              radius: 1.1,
              colors: [
                Color(0xFF8E9CC9),
                Color(0xFF666FA8),
                Color(0xFF383563),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: size * 0.0068,
            ),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: size * 0.016),
              child: Text(
                'അർഥം',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFF4F5FF),
                  fontSize: size * 0.205,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -size * 0.006,
                  shadows: const [
                    Shadow(
                      color: Color(0x667A8DFF),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wordmark lockup for headers and compact brand placements.
class ArthamWordmark extends StatelessWidget {
  final Color? primaryColor;
  final Color? secondaryColor;

  const ArthamWordmark({
    super.key,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ARTHAM',
          style: TextStyle(
            color: primaryColor ?? const Color(0xFFF5F4FF),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.1,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'അർഥം',
          style: TextStyle(
            color: secondaryColor ?? const Color(0xFFBEC2E0),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}
