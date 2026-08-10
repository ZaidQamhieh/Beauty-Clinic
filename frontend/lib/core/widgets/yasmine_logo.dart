import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 5-petal Jasmine SVG/Canvas Logo for Yasmine Beauty Clinic
class YasmineLogo extends StatelessWidget {
  final double size;
  final bool isDarkBackground;

  const YasmineLogo({
    super.key,
    this.size = 40,
    this.isDarkBackground = false,
  });

  @override
  Widget build(BuildContext meContext) {
    return CustomPaint(
      size: Size(size, size),
      painter: _JasminePainter(isDark: isDarkBackground),
    );
  }
}

class _JasminePainter extends CustomPainter {
  final bool isDark;

  _JasminePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    final Color petalColor = isDark ? AppColors.white : AppColors.rose;
    final Color centerColor = isDark ? const Color(0xFFFAE8E4) : AppColors.lav;
    final Color goldColor = isDark ? const Color(0xFFF5EDDA) : AppColors.gold;

    // 5 Petals rotated at 0, 72, 144, 216, 288 deg
    final Paint petalPaint = Paint()
      ..color = petalColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    const List<double> angles = [0, 72, 144, 216, 288];
    for (final deg in angles) {
      final double rad = (deg * math.pi) / 180;
      final double px = 24 + 10 * math.sin(rad);
      final double py = 24 - 10 * math.cos(rad);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rad);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 10, height: 16),
        petalPaint,
      );
      canvas.restore();
    }

    // Outer center circle
    final Paint centerPaint = Paint()
      ..color = centerColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(24, 24), 5, centerPaint);

    // Inner gold dot
    final Paint goldPaint = Paint()
      ..color = goldColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(24, 24), 2.5, goldPaint);

    // Stem curves
    final Paint stemPaint = Paint()
      ..color = petalColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path stemPath = Path();
    stemPath.moveTo(24, 34);
    stemPath.cubicTo(24, 38, 22, 42, 20, 44);
    canvas.drawPath(stemPath, stemPaint);

    final Paint leafPaint = Paint()
      ..color = petalColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path leafPath = Path();
    leafPath.moveTo(22, 40);
    leafPath.cubicTo(19, 38, 17, 36, 18, 33);
    canvas.drawPath(leafPath, leafPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JasminePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
