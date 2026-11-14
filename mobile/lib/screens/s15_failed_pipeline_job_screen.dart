import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S15FailedPipelineJobScreen extends StatefulWidget {
  const S15FailedPipelineJobScreen({super.key});

  @override
  State<S15FailedPipelineJobScreen> createState() =>
      _S15FailedPipelineJobScreenState();
}

class _S15FailedPipelineJobScreenState
    extends State<S15FailedPipelineJobScreen> {
  bool _copied = false;
  bool _rerun = false;

  final String _logOutput =
      '13:58:02 ERROR postgres not ready after 30s\n'
      '13:58:03 ERROR ECONNREFUSED 127.0.0.1:5432\n'
      '13:58:04 FATAL 14 tests failed, exit code 1';

  void _copyLogs() {
    Clipboard.setData(ClipboardData(text: _logOutput));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _doRerun() {
    setState(() => _rerun = true);
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_left, size: 20, color: colors.text),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pipeline #319',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'integration-tests \u00b7 PR #215',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.criticalSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Failed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.critical,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // 5 Stages card
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        _buildStageRow(
                          context,
                          icon: Icon(Icons.check, size: 20, color: colors.success),
                          title: 'Checkout',
                          duration: '12 s',
                          isBold: false,
                        ),
                        Divider(height: 1, indent: 46, color: colors.border),
                        _buildStageRow(
                          context,
                          icon: Icon(Icons.check, size: 20, color: colors.success),
                          title: 'Unit tests \u00b7 42 passed',
                          duration: '48 s',
                          isBold: false,
                        ),
                        Divider(height: 1, indent: 46, color: colors.border),
                        _buildStageRow(
                          context,
                          icon: Icon(Icons.check, size: 20, color: colors.success),
                          title: 'Build image',
                          duration: '35 s',
                          isBold: false,
                        ),
                        Divider(height: 1, indent: 46, color: colors.border),
                        _buildStageRow(
                          context,
                          icon: Icon(Icons.close, size: 20, color: colors.critical),
                          title: 'Integration tests',
                          duration: '2m 14s',
                          isBold: true,
                        ),
                        Divider(height: 1, indent: 46, color: colors.border),
                        _buildStageRow(
                          context,
                          icon: Icon(Icons.circle_outlined, size: 20, color: colors.muted),
                          title: 'Deploy to staging',
                          duration: 'Skipped',
                          isBold: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Failure output header + Copy button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FAILURE OUTPUT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.52,
                          color: colors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: _copyLogs,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            _copied ? 'Copied' : 'Copy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Console box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.codeBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12.5,
                          height: 1.7,
                          color: colors.text,
                        ),
                        children: [
                          const TextSpan(text: '13:58:02 '),
                          TextSpan(
                            text: 'ERROR',
                            style: TextStyle(color: colors.critical, fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' postgres not ready after 30s\n13:58:03 '),
                          TextSpan(
                            text: 'ERROR',
                            style: TextStyle(color: colors.critical, fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' ECONNREFUSED 127.0.0.1:5432\n13:58:04 '),
                          TextSpan(
                            text: 'FATAL',
                            style: TextStyle(color: colors.critical, fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' 14 tests failed, exit code 1'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // AI Explanation card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 18, color: colors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'AI explanation',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The Postgres test container was not ready when tests started, so every test failed to connect. Your code change is probably not the cause.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 14, color: colors.muted),
                            children: [
                              TextSpan(
                                text: 'Suggested fix: ',
                                style: TextStyle(fontWeight: FontWeight.w600, color: colors.text),
                              ),
                              const TextSpan(
                                text: 'wait for the Postgres health check before running tests.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Queued notification banner if rerun
                  if (_rerun) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.successSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Re-run queued as pipeline #321. You will get a push notification with the result.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Buttons row: Open in GitHub | Re-run job
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.open_in_new_rounded, size: 18, color: colors.text),
                            label: Text(
                              'Open in GitHub',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: colors.card,
                              side: BorderSide(color: colors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _rerun ? null : _doRerun,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              _rerun ? 'Queued' : 'Re-run job',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: colors.onAccent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'cicd'),
    );
  }

  Widget _buildStageRow(
    BuildContext context, {
    required Widget icon,
    required String title,
    required String duration,
    required bool isBold,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: colors.text,
              ),
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12.5,
              color: colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
