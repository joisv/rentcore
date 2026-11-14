import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

/// Zero-dependency animated success badge with a concentric soft halo,
/// spring-scaled emerald circle, CustomPainter stroke-draw checkmark,
/// and tactile haptic feedback on mount.
class AnimatedSuccessCheckmark extends StatefulWidget {
  final double size;
  final Color haloColor;
  final Color circleColor;
  final Color checkColor;
  final bool enableHaptics;

  const AnimatedSuccessCheckmark({
    super.key,
    this.size = 88,
    this.haloColor = const Color(0xFFE8F7F0),
    this.circleColor = AppColors.success,
    this.checkColor = Colors.white,
    this.enableHaptics = true,
  });

  @override
  State<AnimatedSuccessCheckmark> createState() =>
      _AnimatedSuccessCheckmarkState();
}

class _AnimatedSuccessCheckmarkState extends State<AnimatedSuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _haloScale;
  late final Animation<double> _haloOpacity;
  late final Animation<double> _circleScale;
  late final Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );

    // Outer soft halo scales gently from 0.6 -> 1.0 with a subtle pulse.
    _haloScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.6,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 68,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.06,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 32,
      ),
    ]).animate(_controller);

    _haloOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 220 / 560, curve: Curves.easeOut),
      ),
    );

    // Inner emerald circle scales with Curves.easeOutBack from 0ms to 350ms.
    _circleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 350 / 560, curve: Curves.easeOutBack),
      ),
    );

    // White checkmark stroke draws cleanly from 200ms to 520ms.
    _checkProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          200 / 560,
          520 / 560,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    if (widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final innerDiameter = widget.size * 0.68;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: _haloOpacity,
            child: ScaleTransition(
              scale: _haloScale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.haloColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          ScaleTransition(
            scale: _circleScale,
            child: Container(
              width: innerDiameter,
              height: innerDiameter,
              decoration: BoxDecoration(
                color: widget.circleColor,
                shape: BoxShape.circle,
              ),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _checkProgress,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _CheckmarkStrokePainter(
                        progress: _checkProgress.value,
                        color: widget.checkColor,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckmarkStrokePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CheckmarkStrokePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.73, size.height * 0.35);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.095).clamp(3.0, 7.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final metrics = path.computeMetrics().toList();
    final totalLength = metrics.fold<double>(
      0.0,
      (sum, metric) => sum + metric.length,
    );
    var remaining = totalLength * progress.clamp(0.0, 1.0);

    for (final PathMetric metric in metrics) {
      if (remaining <= 0) break;
      final segmentLength = remaining.clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(0.0, segmentLength), paint);
      remaining -= segmentLength;
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkStrokePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
