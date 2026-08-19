import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// The one way into the chat.
class AskYasminePill extends StatelessWidget {
  const AskYasminePill({
    super.key,
    required this.onTap,
    this.collapsed = false,
    this.showsClose = false,
  });

  static const height = 48.0;
  static const collapsedSize = 52.0;

  /// Scrolling drops the label, never the button.
  final bool collapsed;

  /// Open on desktop makes it close.
  final bool showsClose;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool iconOnly = collapsed || showsClose;

    return Semantics(
      button: true,
      label: showsClose ? 'Close Yasmine' : 'Ask Yasmine',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: iconOnly ? collapsedSize : height,
            padding: iconOnly
                ? EdgeInsets.zero
                : const EdgeInsets.only(left: 14, right: 20),
            width: iconOnly ? collapsedSize : null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.roseLight, AppColors.roseDark],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x578C5868),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: iconOnly ? _icon(showsClose) : _labelled(),
          ),
        ),
      ),
    );
  }

  Widget _icon(bool close) {
    return Center(
      child: Icon(
        close ? Icons.close_rounded : Icons.auto_awesome,
        color: AppColors.white,
        size: 20,
      ),
    );
  }

  Widget _labelled() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x38FFFFFF),
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: AppColors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Ask Yasmine',
          style: AppTypography.labelMedium(
            color: AppColors.white,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
