import 'package:flutter/material.dart';

import '../services/api_service.dart' show ApiException;
import '../services/developer_assistant_service.dart';
import '../theme/app_colors.dart';
import 'flow_widgets.dart';

/// S23 "Explain a log or error": paste text, the AI explains what it means,
/// the likely cause and what to check next. It only explains; nothing is run
/// or changed. Secrets are removed on the server before the text goes to the AI.
class ExplainPanel extends StatefulWidget {
  final DeveloperAssistantService? service;
  const ExplainPanel({super.key, this.service});

  @override
  State<ExplainPanel> createState() => _ExplainPanelState();
}

class _ExplainPanelState extends State<ExplainPanel> {
  late final DeveloperAssistantService _service =
      widget.service ?? DeveloperAssistantService();
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  Explanation? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _explain() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() => _error = 'Paste a log snippet or an error message first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _service.explain(text);
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : 'Could not explain the text.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final result = _result;
    return FlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 16, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                'Explain a log or error',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a log snippet or error message. Secrets such as passwords and tokens are removed before it is sent to the AI. Nothing is stored, run or changed.',
            style: TextStyle(fontSize: 12, color: colors.muted, height: 1.35),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('explain-input'),
            controller: _controller,
            minLines: 4,
            maxLines: 10,
            maxLength: DeveloperAssistantService.maxLength,
            enabled: !_busy,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: colors.text,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. psycopg2.OperationalError: connection refused',
              hintStyle: TextStyle(fontSize: 12, color: colors.muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          Row(
            children: [
              FilledButton.icon(
                key: const Key('explain-button'),
                onPressed: _busy ? null : _explain,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_busy ? 'Explaining…' : 'Explain'),
              ),
              const SizedBox(width: 8),
              if (!_busy && (_controller.text.isNotEmpty || result != null))
                TextButton(
                  onPressed: () => setState(() {
                    _controller.clear();
                    _result = null;
                    _error = null;
                  }),
                  child: const Text('Clear'),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('explain-error'),
              style: TextStyle(fontSize: 12, color: colors.red),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            FlowSection(label: 'What it means', text: result.meaning),
            if (result.likelyCauses.isNotEmpty)
              FlowSection(label: 'Likely cause', items: result.likelyCauses),
            if (result.nextChecks.isNotEmpty)
              FlowSection(
                label: 'What to check next',
                items: result.nextChecks,
              ),
            const SizedBox(height: 6),
            Text(
              [
                if (result.redactedCount > 0)
                  '${result.redactedCount} secret${result.redactedCount == 1 ? ' was' : 's were'} removed before sending',
                'confidence ${(result.confidence * 100).round()}%',
                if (result.model != null) result.model!,
              ].join(' · '),
              key: const Key('explain-meta'),
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'Explanation only: nothing was run or changed.',
              style: TextStyle(
                fontSize: 11,
                color: colors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
