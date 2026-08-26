import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/chat_api.dart';
import '../data/chat_models.dart';
import 'typing_dots.dart';

/// The floating conversation, never a full page.
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.messages,
    required this.sending,
    required this.onSend,
    required this.onStop,
    required this.onClose,
    required this.onCollapse,
    this.error,
    this.onRetry,
  });

  final List<ChatMessage> messages;
  final bool sending;
  final String? error;

  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final VoidCallback onClose;
  final VoidCallback onCollapse;
  final VoidCallback? onRetry;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  bool get _canSend => _input.text.trim().isNotEmpty && !widget.sending;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTyping);
  }

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length ||
        widget.sending != oldWidget.sending) {
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    _input.removeListener(_onTyping);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTyping() {
    setState(() {});
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _submit() {
    if (!_canSend) return;
    final text = _input.text.trim();
    _input.clear();
    widget.onSend(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x422A2030),
              blurRadius: 54,
              offset: Offset(0, 22),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _header(),
            Expanded(child: _transcript()),
            if (widget.error != null) _errorStrip(),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.roseLight, AppColors.roseDark],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ask Yasmine', style: AppTypography.labelMedium()),
                Text(
                  'Books and cancels for you',
                  style: AppTypography.labelSmall(color: AppColors.sage),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Minimise',
            onPressed: widget.onCollapse,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted,
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _transcript() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      itemCount: widget.messages.length + (widget.sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.messages.length) {
          return _thinking();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _bubble(widget.messages[index]),
        );
      },
    );
  }

  Widget _bubble(ChatMessage message) {
    final bool mine = message.author == ChatAuthor.patient;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 262),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? AppColors.roseDark : AppColors.bgAlt,
            border: mine ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(15),
              topRight: const Radius.circular(15),
              bottomLeft: Radius.circular(mine ? 15 : 5),
              bottomRight: Radius.circular(mine ? 5 : 15),
            ),
          ),
          child: Text(
            message.text,
            style: AppTypography.bodySmall(
              color: mine ? AppColors.white : AppColors.text,
            ).copyWith(height: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _thinking() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const TypingDots(),
      ),
    );
  }

  Widget _errorStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      color: AppColors.bgRose,
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.error!,
              style: AppTypography.labelSmall(color: AppColors.roseDark),
            ),
          ),
          if (widget.onRetry != null)
            TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              maxLength: ChatApi.messageLimit,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              style: AppTypography.bodySmall(color: AppColors.text),
              buildCounter:
                  (
                    _, {
                    required int currentLength,
                    required bool isFocused,
                    int? maxLength,
                  }) => null,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.bg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.roseLight),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          _sendButton(),
        ],
      ),
    );
  }

  Widget _sendButton() {
    // Sending turns the disc into a stop.
    if (widget.sending) {
      return _disc(
        icon: Icons.stop_rounded,
        onTap: widget.onStop,
        tooltip: 'Stop',
      );
    }

    if (!_canSend) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgAlt,
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.send_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
      );
    }

    return _disc(icon: Icons.send_rounded, onTap: _submit, tooltip: 'Send');
  }

  Widget _disc({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.roseDark,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 16, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}
