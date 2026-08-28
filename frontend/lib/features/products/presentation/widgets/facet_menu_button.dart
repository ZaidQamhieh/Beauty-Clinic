import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/menu_anchor_host.dart';

/// One product filter facet, as menu.
class FacetMenuButton extends StatefulWidget {
  const FacetMenuButton({
    super.key,
    required this.label,
    required this.counts,
    required this.selected,
    required this.onToggle,
    required this.onClear,
    this.labelFor,
  });

  final String label;

  /// Option value to product count.
  final Map<String, int> counts;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  /// Raw value to reader-facing label.
  final String Function(String value)? labelFor;

  @override
  State<FacetMenuButton> createState() => _FacetMenuButtonState();
}

class _FacetMenuButtonState extends State<FacetMenuButton> with MenuAnchorHost {
  final MenuController _menu = MenuController();
  final GlobalKey _anchorKey = GlobalKey();

  @override
  MenuController get menuController => _menu;

  @override
  GlobalKey get menuAnchorKey => _anchorKey;

  @override
  double get preferredMenuHeight => 320;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final counts = widget.counts;
    final labelFor = widget.labelFor;
    final active = selected.isNotEmpty;

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, menuGap),
      consumeOutsideTap: true,
      onOpen: handleMenuOpen,
      onClose: handleMenuClose,
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.bgCard),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      menuChildren: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxMenuHeight, minWidth: 230),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in counts.entries)
                  _Option(
                    label: labelFor?.call(entry.key) ?? entry.key,
                    count: entry.value,
                    checked: selected.contains(entry.key),
                    onTap: () => widget.onToggle(entry.key),
                  ),
                if (active) ...[
                  const Divider(height: 13, color: AppColors.hairline),
                  InkWell(
                    onTap: widget.onClear,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Clear',
                            style: AppTypography.bodySmall(
                              color: AppColors.roseDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, _) {
        // Key rides the trigger, for measuring.
        return InkWell(
          key: _anchorKey,
          borderRadius: BorderRadius.circular(12),
          onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? AppColors.bgRose : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppColors.rose : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: AppTypography.bodyMedium(
                    color: active ? AppColors.roseDark : AppColors.textSub,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.rose,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${selected.length}',
                      style: AppTypography.numeric(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: active ? AppColors.roseDark : AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.count,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: checked ? AppColors.bgRose : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: checked ? AppColors.rose : AppColors.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: checked ? AppColors.rose : AppColors.border,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 12, color: AppColors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium(
                  color: checked ? AppColors.roseDark : AppColors.textSub,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count',
              style: AppTypography.numeric(
                color: checked ? AppColors.roseDark : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
