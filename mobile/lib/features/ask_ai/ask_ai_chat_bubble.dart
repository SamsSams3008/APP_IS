import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/ask_ai_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/locale_notifier.dart';

/// Burbuja flotante abajo a la derecha que abre el chat con la IA.
class AskAiChatBubble extends StatelessWidget {
  const AskAiChatBubble({
    super.key,
    required this.dataSummary,
  });

  final String? dataSummary;

  bool get _backendConfigured => kAskAiBackendUrl.isNotEmpty;

  void _openChat(BuildContext context) {
    if (!_backendConfigured) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AskAiChatSheet(dataSummary: dataSummary),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_backendConfigured) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : colorScheme.primaryContainer;
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.95)
        : colorScheme.onPrimaryContainer;
    return Positioned(
      right: 16,
      bottom: 16,
      child: Material(
        elevation: isDark ? 8 : 6,
        borderRadius: BorderRadius.circular(30),
        color: bgColor,
        child: InkWell(
          onTap: () => _openChat(context),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_awesome,
              size: 30,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.role, required this.text});
  final String role;
  final String text;
}

class _AskAiChatSheet extends StatefulWidget {
  const _AskAiChatSheet({required this.dataSummary});

  final String? dataSummary;

  @override
  State<_AskAiChatSheet> createState() => _AskAiChatSheetState();
}

class _AskAiChatSheetState extends State<_AskAiChatSheet> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final question = text.trim();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: question));
      _loading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final data = widget.dataSummary ??
        'No dashboard data. Basic info only: current time, date.';

    try {
      final res = await http.post(
        Uri.parse(kAskAiBackendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': question,
          'dataSummary': data,
        }),
      );
      if (!mounted) return;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        final err = json['error'] as String? ?? 'Error';
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', text: err));
          _loading = false;
        });
        _scrollToBottom();
        return;
      }
      final responseText = json['text'] as String? ?? 'No response.';
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: responseText.trim()));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', text: 'Error: $e'));
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final t = _inputController.text.trim();
    if (t.isEmpty) return;
    _sendMessage(t);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = MediaQuery.of(context).size.height;
    return Container(
      height: h * 0.7,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Text(
                  AppStrings.t('ask_ai_title', LocaleNotifier.current),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
                  );
                }
                final m = _messages[i];
                final isUser = m.role == 'user';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment:
                        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) const SizedBox(width: 12),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(
                            m.text,
                            style: TextStyle(
                              height: 1.4,
                              color: isUser
                                  ? cs.onPrimaryContainer
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (isUser) const SizedBox(width: 12),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.85),
                    ),
                    decoration: InputDecoration(
                      hintText: AppStrings.t('ask_ai_input_example', LocaleNotifier.current),
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 2,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
