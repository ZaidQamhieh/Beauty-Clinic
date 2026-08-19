import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Floating decorative petals with continuous subtle drift animation
class FloatingPetals extends StatefulWidget {
  const FloatingPetals({super.key});

  @override
  State<FloatingPetals> createState() => _FloatingPetalsState();
}

class _FloatingPetalsState extends State<FloatingPetals>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
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
      builder: (context, child) {
        final double t = _controller.value * 2 * math.pi;
        final double dy = math.sin(t) * 6;
        final double dx = math.cos(t * 0.7) * 4;

        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                top: 80 + dy,
                left: 30 + dx,
                child: _buildPetal(28, 20),
              ),
              Positioned(
                top: 180 - dy,
                right: 40 + dx,
                child: _buildPetal(22, -15),
              ),
              Positioned(
                bottom: 220 + dy,
                left: 50 - dx,
                child: _buildPetal(24, 40),
              ),
              Positioned(
                bottom: 100 - dy,
                right: 60 + dx,
                child: _buildPetal(20, -30),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPetal(double size, double rotationDeg) {
    return Transform.rotate(
      angle: rotationDeg * math.pi / 180,
      child: Opacity(
        opacity: 0.25,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _PetalPainter()),
        ),
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p1 = Paint()
      ..color = AppColors.rose.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final Paint p2 = Paint()
      ..color = AppColors.roseLight.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final Rect outer = Rect.fromLTWH(0, 0, size.width, size.height);
    final Rect inner = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.15,
      size.width * 0.7,
      size.height * 0.7,
    );

    canvas.drawOval(outer, p1);
    canvas.drawOval(inner, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
