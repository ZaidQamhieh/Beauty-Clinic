import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// Opens flush under the trigger.
const _menuStyle = MenuStyle(
  backgroundColor: WidgetStatePropertyAll(AppColors.bgCard),
  surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
  elevation: WidgetStatePropertyAll(4),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      side: BorderSide(color: AppColors.border),
    ),
  ),
);

List<Widget> _menuItems<T>({
  required List<DropdownMenuItem<T>> items,
  required T? value,
  required MenuController menu,
  required ValueChanged<T?> onChanged,
}) {
  return [
    for (final item in items)
      MenuItemButton(
        onPressed: () {
          menu.close();
          onChanged(item.value);
        },
        style: MenuItemButton.styleFrom(
          minimumSize: const Size.fromHeight(36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: AppTypography.bodyMedium(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: item.value == value ? AppColors.rosePale : null,
        ),
        child: item.child,
      ),
  ];
}

DropdownMenuItem<T>? _selectedOf<T>(List<DropdownMenuItem<T>> items, T? value) {
  for (final item in items) {
    if (item.value == value) return item;
  }
  return null;
}

// Drop-in DropdownButtonFormField replacement.
class AppDropdownField<T> extends FormField<T> {
  AppDropdownField({
    super.key,
    super.initialValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    InputDecoration decoration = const InputDecoration(),
    super.validator,
  }) : super(
         builder: (field) {
           return _DropdownFieldBody<T>(
             value: field.value,
             items: items,
             decoration: decoration,
             errorText: field.errorText,
             onChanged: (next) {
               field.didChange(next);
               onChanged(next);
             },
           );
         },
       );
}

class _DropdownFieldBody<T> extends StatefulWidget {
  const _DropdownFieldBody({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.decoration,
    required this.errorText,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;
  final String? errorText;

  @override
  State<_DropdownFieldBody<T>> createState() => _DropdownFieldBodyState<T>();
}

class _DropdownFieldBodyState<T> extends State<_DropdownFieldBody<T>> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOf(widget.items, widget.value);
    return LayoutBuilder(
      builder: (context, constraints) {
        return MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(0, 4),
          onOpen: () => setState(() {}),
          onClose: () => setState(() {}),
          style: _menuStyle,
          menuChildren: [
            SizedBox(
              width: constraints.maxWidth,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _menuItems(
                      items: widget.items,
                      value: widget.value,
                      menu: _menu,
                      onChanged: widget.onChanged,
                    ),
                  ),
                ),
              ),
            ),
          ],
          builder: (context, controller, child) => InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
            child: InputDecorator(
              decoration: widget.decoration.copyWith(
                errorText: widget.errorText,
                suffixIcon: Icon(
                  _menu.isOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
              ),
              child:
                  selected?.child ??
                  Text('', style: AppTypography.bodyMedium()),
            ),
          ),
        );
      },
    );
  }
}

// Drop-in DropdownButton replacement for filter bars.
class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Widget? hint;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOf(widget.items, widget.value);
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 4),
      onOpen: () => setState(() {}),
      onClose: () => setState(() {}),
      style: _menuStyle,
      menuChildren: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 180, maxHeight: 300),
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _menuItems(
                items: widget.items,
                value: widget.value,
                menu: _menu,
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle(
                style: AppTypography.bodyMedium(),
                child:
                    selected?.child ?? widget.hint ?? const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
              Icon(
                _menu.isOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
