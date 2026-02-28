import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/config/ask_ai_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/locale_notifier.dart';

class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key, this.dataSummary});

  final String? dataSummary;

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final TextEditingController _questionController = TextEditingController();
  String _response = '';
  bool _loading = false;

  bool get _backendConfigured => kAskAiBackendUrl.isNotEmpty;

  Future<void> _ask() async {
    if (!_backendConfigured) return;
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _response = 'Type a question about your data.');
      return;
    }
    final data = widget.dataSummary ?? 'No dashboard data loaded. Open Ask AI from the dashboard after loading your stats.';

    setState(() {
      _loading = true;
      _response = '';
    });

    try {
      final res = await http.post(
        Uri.parse(kAskAiBackendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question, 'dataSummary': data}),
      );
      if (!mounted) return;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _response = 'Error: ${json['error'] ?? res.statusCode}';
        });
        return;
      }
      final text = json['text'] as String? ?? 'No response.';
      setState(() {
        _loading = false;
        _response = text.trim();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _response = 'Error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_backendConfigured) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.t('ask_ai_title', LocaleNotifier.current)),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ask AI is not configured yet.\nThe developer needs to set the backend URL in the app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask about your data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _questionController,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
              decoration: InputDecoration(
                hintText: AppStrings.t('ask_ai_input_hint', LocaleNotifier.current),
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
                border: const OutlineInputBorder(),
                labelText: 'Your question',
              ),
              maxLines: 2,
              onSubmitted: (_) => _ask(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: Text(_loading ? 'Asking...' : 'Ask'),
            ),
            if (_response.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Answer', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(_response, style: const TextStyle(height: 1.4)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
