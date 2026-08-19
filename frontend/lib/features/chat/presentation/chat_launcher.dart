import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/chat_api.dart';
import '../data/chat_models.dart';
import 'ask_yasmine_pill.dart';
import 'chat_panel.dart';

/// Lays the pill and bubble over pages.
class ChatLauncher extends StatefulWidget {
  const ChatLauncher({
    super.key,
    required this.api,
    required this.child,
    this.onVisitsChanged,
  });

  final ChatApi api;
  final Widget child;

  /// Fires after a turn that wrote.
  final VoidCallback? onVisitsChanged;

  @override
  State<ChatLauncher> createState() => _ChatLauncherState();
}

class _ChatLauncherState extends State<ChatLauncher> {
  static const _mobileWidth = 900.0;
  static const _openingMessage = 'hi';

  final List<ChatMessage> _messages = [];

  bool _open = false;
  bool _collapsed = false;
  bool _sending = false;
  String? _error;
  CancelToken? _inFlight;
  Timer? _scrollIdle;

  String? _retryMessage;

  @override
  void dispose() {
    _scrollIdle?.cancel();
    _inFlight?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      _collapsed = false;
    });
    if (_open && _messages.isEmpty) {
      unawaited(_send(_openingMessage, showPatient: false));
    }
  }

  void _close() {
    _inFlight?.cancel();
    setState(() {
      _open = false;
      _sending = false;
      _inFlight = null;
    });
  }

  Future<void> _send(String message, {bool showPatient = true}) async {
    final token = CancelToken();
    setState(() {
      if (showPatient) {
        _messages.add(ChatMessage.patient(message));
      }
      _sending = true;
      _error = null;
      _inFlight = token;
      _retryMessage = message;
    });

    try {
      final reply = await widget.api.send(
        message: message,
        history: List.unmodifiable(_messages),
        cancelToken: token,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage.bot(reply.text));
        _sending = false;
        _inFlight = null;
      });
      // The server says when it wrote.
      if (reply.wrote) {
        widget.onVisitsChanged?.call();
      }
    } on ChatUnavailableException {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _inFlight = null;
        _error = 'Yasmine could not answer just now.';
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _inFlight = null;
      });
    }
  }

  void _stop() {
    _inFlight?.cancel();
  }

  void _retry() {
    final message = _retryMessage;
    if (message == null) return;
    unawaited(_send(message, showPatient: false));
  }

  bool _onScroll(ScrollNotification notification, bool isMobile) {
    if (!isMobile || _open || notification.depth > 0) {
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      if (!_collapsed) {
        setState(() => _collapsed = true);
      }
      _scrollIdle?.cancel();
      _scrollIdle = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _collapsed = false);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width < _mobileWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double inset = isMobile ? 16 : 24;
        final bool showPill = !_open || !isMobile;

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) =>
                  _onScroll(notification, isMobile),
              child: widget.child,
            ),
            if (_open) _positionedPanel(constraints, isMobile),
            if (showPill)
              Positioned(
                right: inset,
                bottom: inset,
                child: AskYasminePill(
                  collapsed: _collapsed && !_open,
                  showsClose: _open,
                  onTap: _toggle,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _positionedPanel(BoxConstraints constraints, bool isMobile) {
    final panel = ChatPanel(
      messages: _messages,
      sending: _sending,
      error: _error,
      onRetry: _error == null ? null : _retry,
      onSend: _send,
      onStop: _stop,
      onClose: _close,
      onCollapse: _close,
    );

    if (isMobile) {
      final double height = math.min(430, constraints.maxHeight - 60);
      return Positioned(
        left: 12,
        right: 12,
        bottom: 14,
        height: math.max(height, 240),
        child: panel,
      );
    }

    final double height = math.min(516, constraints.maxHeight - 110);
    return Positioned(
      right: 24,
      bottom: 86,
      width: 340,
      height: math.max(height, 300),
      child: panel,
    );
  }
}
