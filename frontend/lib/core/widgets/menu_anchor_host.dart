import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gap between a trigger and its menu.
const double menuGap = 4;

const double _minMenuHeight = 132;

/// Open, measure and close behaviour for menus.
mixin MenuAnchorHost<W extends StatefulWidget> on State<W> {
  ScrollPosition? _watched;
  double _room = double.infinity;

  MenuController get menuController;

  /// Key on the menu trigger.
  GlobalKey get menuAnchorKey;

  /// Tallest the menu should ever be.
  double get preferredMenuHeight => 300;

  /// Capped by the room beside the trigger.
  double get maxMenuHeight => math.min(preferredMenuHeight, _room);

  void handleMenuOpen() {
    setState(() {
      _room = _measureRoom();
      _watched = Scrollable.maybeOf(context)?.position;
      _watched?.addListener(_closeMenu);
    });
  }

  void handleMenuClose() {
    setState(_release);
  }

  /// Uses the roomier side of the trigger.
  double _measureRoom() {
    final box = menuAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return double.infinity;

    final media = MediaQuery.of(context);
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewBottom =
        media.size.height - media.viewInsets.bottom - media.padding.bottom;

    final room = math.max(
      viewBottom - bottom - menuGap * 2,
      top - media.padding.top - menuGap * 2,
    );
    return math.max(_minMenuHeight, room);
  }

  void _release() {
    _watched?.removeListener(_closeMenu);
    _watched = null;
  }

  void _closeMenu() {
    if (menuController.isOpen) menuController.close();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }
}
