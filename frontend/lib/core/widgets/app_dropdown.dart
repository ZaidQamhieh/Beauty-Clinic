import 'dart:math' as math;

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

const double _itemHeight = 36;
const double _menuGap = 4;
const double _preferredMenuHeight = 300;
const double _minMenuHeight = 132;
const double _searchFieldHeight = 44;

// Long lists get a filter field.
const int _searchThreshold = 12;

DropdownMenuItem<T>? _selectedOf<T>(List<DropdownMenuItem<T>> items, T? value) {
  for (final item in items) {
    if (item.value == value) return item;
  }
  return null;
}

/// Menu height that never covers the trigger.
double _menuHeightFor(BuildContext context, GlobalKey anchorKey) {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return _preferredMenuHeight;

  final media = MediaQuery.of(context);
  final top = box.localToGlobal(Offset.zero).dy;
  final bottom = top + box.size.height;
  final viewTop = media.padding.top;
  final viewBottom =
      media.size.height - media.viewInsets.bottom - media.padding.bottom;

  final below = viewBottom - bottom - _menuGap * 2;
  final above = top - viewTop - _menuGap * 2;
  final room = math.max(below, above);
  return math.max(_minMenuHeight, math.min(_preferredMenuHeight, room));
}

class _DropdownMenuBody<T> extends StatefulWidget {
  const _DropdownMenuBody({
    required this.items,
    required this.value,
    required this.menu,
    required this.onChanged,
    required this.maxHeight,
    this.width,
    this.minWidth,
    this.labelOf,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final MenuController menu;
  final ValueChanged<T?> onChanged;
  final double maxHeight;
  final double? width;
  final double? minWidth;

  /// Enables the filter field on long lists.
  final String Function(T value)? labelOf;

  @override
  State<_DropdownMenuBody<T>> createState() => _DropdownMenuBodyState<T>();
}

class _DropdownMenuBodyState<T> extends State<_DropdownMenuBody<T>> {
  late final ScrollController _scroll;
  final TextEditingController _query = TextEditingController();
  late List<DropdownMenuItem<T>> _visible;

  bool get _searchable =>
      widget.labelOf != null && widget.items.length > _searchThreshold;

  double get _listHeight =>
      widget.maxHeight - (_searchable ? _searchFieldHeight : 0);

  @override
  void initState() {
    super.initState();
    _visible = widget.items;
    _scroll = ScrollController(initialScrollOffset: _selectedOffset());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Centres the current value.
  double _selectedOffset() {
    final index = widget.items.indexWhere((item) => item.value == widget.value);
    if (index <= 0) return 0;
    final extent = widget.items.length * _itemHeight;
    final maxOffset = math.max(0.0, extent - _listHeight);
    final centred = index * _itemHeight - _listHeight / 2 + _itemHeight / 2;
    return centred.clamp(0.0, maxOffset);
  }

  void _filter(String text) {
    final needle = text.trim().toLowerCase();
    final labelOf = widget.labelOf;
    setState(() {
      _visible = needle.isEmpty || labelOf == null
          ? widget.items
          : widget.items.where((item) {
              final value = item.value;
              if (value == null) return true;
              return labelOf(value).toLowerCase().contains(needle);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minWidth ?? 0,
          maxHeight: widget.maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_searchable) _searchField(),
            Flexible(child: _list()),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: _query,
          autofocus: true,
          onChanged: _filter,
          style: AppTypography.bodyMedium(),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Type to filter',
            hintStyle: AppTypography.bodySmall(color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            prefixIcon: const Icon(
              Icons.search,
              size: 16,
              color: AppColors.textMuted,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            border: _fieldBorder(AppColors.border),
            enabledBorder: _fieldBorder(AppColors.border),
            focusedBorder: _fieldBorder(AppColors.rose),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _list() {
    if (_visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          'Nothing matches',
          style: AppTypography.bodySmall(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      primary: false,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemExtent: _itemHeight,
      itemCount: _visible.length,
      itemBuilder: (context, index) {
        final item = _visible[index];
        return MenuItemButton(
          onPressed: () {
            widget.menu.close();
            widget.onChanged(item.value);
          },
          style: MenuItemButton.styleFrom(
            minimumSize: const Size.fromHeight(_itemHeight),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: AppTypography.bodyMedium(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: item.value == widget.value
                ? AppColors.rosePale
                : null,
          ),
          child: item.child,
        );
      },
    );
  }
}

// Drop-in DropdownButtonFormField replacement.
class AppDropdownField<T> extends FormField<T> {
  AppDropdownField({
    super.key,
    super.initialValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    InputDecoration decoration = const InputDecoration(),
    String Function(T value)? labelOf,
    super.validator,
  }) : super(
         builder: (field) {
           return _DropdownFieldBody<T>(
             value: field.value,
             items: items,
             decoration: decoration,
             errorText: field.errorText,
             labelOf: labelOf,
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
    required this.labelOf,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;
  final String? errorText;
  final String Function(T value)? labelOf;

  @override
  State<_DropdownFieldBody<T>> createState() => _DropdownFieldBodyState<T>();
}

class _DropdownFieldBodyState<T> extends State<_DropdownFieldBody<T>>
    with _ClosesOnScroll {
  final MenuController _menu = MenuController();
  final GlobalKey _anchorKey = GlobalKey();

  @override
  MenuController get menu => _menu;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOf(widget.items, widget.value);
    return LayoutBuilder(
      builder: (context, constraints) {
        return MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(0, _menuGap),
          consumeOutsideTap: true,
          onOpen: () => setState(watchScroll),
          onClose: () => setState(unwatchScroll),
          style: _menuStyle,
          menuChildren: [
            _DropdownMenuBody<T>(
              items: widget.items,
              value: widget.value,
              menu: _menu,
              onChanged: widget.onChanged,
              labelOf: widget.labelOf,
              maxHeight: _menuHeightFor(context, _anchorKey),
              width: constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : null,
              minWidth: constraints.maxWidth.isFinite ? null : 180,
            ),
          ],
          builder: (context, controller, child) => InkWell(
            key: _anchorKey,
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
    this.labelOf,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Widget? hint;

  /// Enables the filter field on long lists.
  final String Function(T value)? labelOf;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> with _ClosesOnScroll {
  final MenuController _menu = MenuController();
  final GlobalKey _anchorKey = GlobalKey();

  @override
  MenuController get menu => _menu;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOf(widget.items, widget.value);
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, _menuGap),
      consumeOutsideTap: true,
      onOpen: () => setState(watchScroll),
      onClose: () => setState(unwatchScroll),
      style: _menuStyle,
      menuChildren: [
        _DropdownMenuBody<T>(
          items: widget.items,
          value: widget.value,
          menu: _menu,
          onChanged: widget.onChanged,
          labelOf: widget.labelOf,
          maxHeight: _menuHeightFor(context, _anchorKey),
          minWidth: 180,
        ),
      ],
      builder: (context, controller, child) => InkWell(
        key: _anchorKey,
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

/// Closes an open menu on scroll.
mixin _ClosesOnScroll<W extends StatefulWidget> on State<W> {
  ScrollPosition? _watched;

  MenuController get menu;

  void watchScroll() {
    _watched = Scrollable.maybeOf(context)?.position;
    _watched?.addListener(_close);
  }

  void unwatchScroll() {
    _watched?.removeListener(_close);
    _watched = null;
  }

  void _close() {
    if (menu.isOpen) menu.close();
  }

  @override
  void dispose() {
    unwatchScroll();
    super.dispose();
  }
}
