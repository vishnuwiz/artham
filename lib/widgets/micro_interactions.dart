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
