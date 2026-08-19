import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Three dots that bounce while Yasmine thinks.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  static const _dots = 3;
  static const _dotSize = 7.0;
  static const _hop = 5.0;

  // Each dot starts after the last.
  static const _stagger = 0.15;

  // Share of the cycle spent hopping.
  static const _hopShare = 0.4;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_dots, (index) {
            final double lift = _lift(index);

            return Padding(
              padding: EdgeInsets.only(right: index == _dots - 1 ? 0 : 5),
              child: Transform.translate(
                offset: Offset(0, -_hop * lift),
                child: Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.roseLight.withValues(
                      alpha: 0.45 + (0.55 * lift),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// Zero on ground, one at top.
  double _lift(int index) {
    final double phase = (_controller.value - (index * _stagger)) % 1.0;
    if (phase > _hopShare) {
      return 0;
    }

    return math.sin((phase / _hopShare) * math.pi);
  }
}
