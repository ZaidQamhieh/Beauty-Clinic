import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/enum_label.dart';
import '../data/treatment.dart';

/// The treatment filter, owning its controller.
class BookingTreatmentField extends StatefulWidget {
  const BookingTreatmentField({
    super.key,
    required this.treatments,
    required this.alreadyInVisit,
    required this.selected,
    required this.onChanged,
  });

  final List<Treatment> treatments;
  final Set<String> alreadyInVisit;
  final Treatment? selected;
  final ValueChanged<Treatment?> onChanged;

  @override
  State<BookingTreatmentField> createState() => _BookingTreatmentFieldState();
}

class _BookingTreatmentFieldState extends State<BookingTreatmentField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.selected?.label ?? '',
  );

  final MenuController _menu = MenuController();
  final FocusNode _focus = FocusNode();

  /// Set while the field mirrors a selection.
  bool _syncing = false;

  /// Null means every category.
  String? _category;

  bool get _empty => _controller.text.isEmpty;

  // Catalogue order, one entry per category.
  List<String> get _categories {
    final seen = <String>[];
    for (final treatment in widget.treatments) {
      if (!seen.contains(treatment.category)) seen.add(treatment.category);
    }
    return seen;
  }

  // Typed text narrows, unless naming the pick.
  List<Treatment> get _visible {
    final query = _controller.text.trim().toLowerCase();
    final chosen = widget.selected?.label.toLowerCase();
    final typed = query.isEmpty || query == chosen ? '' : query;
    return widget.treatments.where((treatment) {
      final inCategory = _category == null || treatment.category == _category;
      final matches =
          typed.isEmpty || treatment.label.toLowerCase().contains(typed);
      return inCategory && matches;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  // Emptied by hand drops the filter.
  void _onTextChanged() {
    if (_syncing) return;
    setState(() {});
    if (_empty && widget.selected != null) {
      widget.onChanged(null);
    }
  }

  // Mirrors a selection without re-entering the listener.
  void _setText(String text) {
    _syncing = true;
    _controller.text = text;
    _syncing = false;
  }

  void _select(Treatment treatment) {
    _setText(treatment.label);
    _menu.close();
    widget.onChanged(treatment);
  }

  // Clears typed text and selection.
  void _clear() {
    _setText('');
    setState(() {});
    widget.onChanged(null);
  }

  // Typed text compounds with a narrowed list.
  void _pickCategory(String? category) {
    setState(() {
      _category = category;
      if (category != null) _setText('');
    });
    if (category != null && widget.selected != null) {
      widget.onChanged(null);
    }
  }

  // A selection made elsewhere reaches the field.
  @override
  void didUpdateWidget(covariant BookingTreatmentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final label = widget.selected?.label ?? '';
    if (widget.selected != oldWidget.selected && _controller.text != label) {
      _setText(label);
    }
    // A selection outside the filter hides itself.
    if (widget.selected != null && widget.selected!.category != _category) {
      _category = null;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Pinned above the list, outside its scroll.
  Widget _categoryBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          _categoryChip('All', _category == null, () => _pickCategory(null)),
          for (final category in _categories) ...[
            const SizedBox(width: 6),
            _categoryChip(
              humanizeEnum(category),
              _category == category,
              () => _pickCategory(category),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChip(String label, bool active, VoidCallback onTap) {
    return Material(
      color: active ? AppColors.rosePale : AppColors.bgAlt,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.borderRose : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall(
              color: active ? AppColors.roseDark : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _treatmentItem(Treatment treatment) {
    final held = widget.alreadyInVisit.contains(treatment.name);
    return MenuItemButton(
      // Once a visit, so row says why.
      onPressed: held ? null : () => _select(treatment),
      leadingIcon: Icon(
        held ? Icons.check_circle_outline : Icons.spa_outlined,
        size: 18,
        color: held ? AppColors.sage : AppColors.rose,
      ),
      trailingIcon: Text(
        held ? 'in this visit' : '${treatment.durationMinutes} min',
        style: AppTypography.bodySmall(),
      ),
      style: MenuItemButton.styleFrom(
        minimumSize: const Size.fromHeight(36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: AppTypography.bodyMedium(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(treatment.label),
    );
  }

  Widget _clearButton() {
    return IconButton(
      icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
      tooltip: 'Clear treatment',
      splashRadius: 18,
      onPressed: _clear,
    );
  }

  Widget _field() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: AppTypography.bodyMedium(),
      onTap: _menu.open,
      // The magnifier now really filters.
      onChanged: (_) {
        if (!_menu.isOpen) _menu.open();
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.bgCard,
        hintText: 'Search treatments',
        hintStyle: AppTypography.bodyMedium(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.rose),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        // Empty field has nothing to clear.
        suffixIcon: _empty
            ? IconButton(
                icon: Icon(
                  _menu.isOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
                onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
              )
            : _clearButton(),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.rose),
        ),
      ),
    );
  }

  // Own scroll, so the bar stays put.
  Widget _menuPanel(double width) {
    final visible = _visible;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _categoryBar(),
          const Divider(height: 1, color: AppColors.hairline),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            // Own scroll position, not the page's.
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Text(
                        'No treatments in this category.',
                        style: AppTypography.bodySmall(),
                      ),
                    ),
                  for (final treatment in visible) _treatmentItem(treatment),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Menu is sized to its field.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(0, 4),
          // Repaints the chevron, which reads the menu.
          onOpen: () => setState(() {}),
          onClose: () => setState(() {}),
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.bgCard),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(4),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 4),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          menuChildren: [_menuPanel(width)],
          builder: (context, controller, child) => _field(),
        );
      },
    );
  }
}
