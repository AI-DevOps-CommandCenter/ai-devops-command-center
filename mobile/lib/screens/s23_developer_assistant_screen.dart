import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S23DeveloperAssistantScreen extends StatefulWidget {
  final String? initialContext;

  const S23DeveloperAssistantScreen({
    super.key,
    this.initialContext,
  });

  @override
  State<S23DeveloperAssistantScreen> createState() => _S23DeveloperAssistantScreenState();
}

class _S23DeveloperAssistantScreenState extends State<S23DeveloperAssistantScreen> {
  final List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text': 'Pick a prompt. Answers are contextualized for this incident investigation.',
      'ref': '',
    },
  ];

  final Map<String, Map<String, String>> _cannedQA = {
    'logs': {
      'q': 'Why are there connection timeouts?',
      'a': 'The timeouts start 2 min after v2.8.1 went live. The new build sets DB_POOL_TIMEOUT=500ms (was 5000ms). This is a hypothesis supported by timing, not proof.',
      'ref': 'Ref: Loki payments-api 14:07–14:12; deploy #318',
    },
    'build': {
      'q': 'Explain the failed build',
      'a': 'Job "integration-tests" failed: Postgres service did not start within 30 s, so 14 tests errored with ECONNREFUSED. Likely a CI service timeout rather than a code bug.',
      'ref': 'Ref: pipeline #318, step 4',
    },
    'pr': {
      'q': 'Summarize PR #214',
      'a': 'PR #214 "Tune DB pool settings" changes 3 files. Concern: it lowers the pool timeout from 5 s to 0.5 s and has no load test.',
      'ref': 'Ref: PR #214, commit a91f3c2',
    },
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialContext != null && _cannedQA.containsKey(widget.initialContext)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _askContext(widget.initialContext!);
      });
    }
  }

  void _askContext(String ctx) {
    final qa = _cannedQA[ctx];
    if (qa == null) return;

    setState(() {
      _messages.add({
        'sender': 'user',
        'text': qa['q']!,
        'ref': '',
      });
      _messages.add({
        'sender': 'bot',
        'text': qa['a']!,
        'ref': qa['ref']!,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.text, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Assistant',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),

            // Prompt Action Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildPromptChip(colors, 'Logs', 'logs'),
                  const SizedBox(width: 8),
                  _buildPromptChip(colors, 'Build error', 'build'),
                  const SizedBox(width: 8),
                  _buildPromptChip(colors, 'Pull request', 'pr'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Chat Messages List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                itemCount: _messages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['sender'] == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.82,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser ? colors.badgeTealBg : colors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isUser ? colors.teal.withOpacity(0.3) : colors.cardBorder,
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.isDark ? Colors.black.withOpacity(0.25) : const Color.fromRGBO(15, 27, 51, 0.04),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['text']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.text,
                              height: 1.4,
                              fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (msg['ref'] != null && msg['ref']!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              msg['ref']!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.muted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 's23'),
    );
  }

  Widget _buildPromptChip(AppColorScheme colors, String label, String contextKey) {
    return InkWell(
      onTap: () => _askContext(contextKey),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.muted,
          ),
        ),
      ),
    );
  }
}
