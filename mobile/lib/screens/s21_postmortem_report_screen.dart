import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';

class S21PostmortemReportScreen extends StatefulWidget {
  const S21PostmortemReportScreen({super.key});

  @override
  State<S21PostmortemReportScreen> createState() => _S21PostmortemReportScreenState();
}

class _S21PostmortemReportScreenState extends State<S21PostmortemReportScreen> {
  bool _shared = false;
  bool _resolved = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: padding: 14px 16px 10px, gap: 10px
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Postmortem',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'INC-1042 · generated 14:34',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content: padding: 4px 16px 24px, gap: 14px
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stepper: Detect(ok), Investigate(ok), Cause(ok), Approve(ok), Recover(ok), Report(active)
                    _buildStepper(context, activeStage: 5),
                    const SizedBox(height: 14),

                    // Summary Card
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
                          Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.52,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'payments-api returned errors after v2.8.1 lowered the DB pool timeout. Rolling back to v2.8.0 fixed it.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3-column Impact Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildImpactCard(
                            label: 'Impact',
                            value: '20 min',
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildImpactCard(
                            label: 'Peak errors',
                            value: '12.4%',
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildImpactCard(
                            label: 'Time to fix',
                            value: '15 min',
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Timeline Card
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
                          Text(
                            'Timeline',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.52,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildTimelineItem(
                            time: '14:05',
                            title: 'v2.8.1 deployed',
                            sub: 'PR #214',
                            dotColor: colors.info,
                            isLast: false,
                            colors: colors,
                          ),
                          _buildTimelineItem(
                            time: '14:07',
                            title: 'Timeouts begin',
                            sub: 'Loki',
                            dotColor: colors.warning,
                            isLast: false,
                            colors: colors,
                          ),
                          _buildTimelineItem(
                            time: '14:12',
                            title: 'Alert fired',
                            sub: 'Prometheus',
                            dotColor: colors.critical,
                            isLast: false,
                            colors: colors,
                          ),
                          _buildTimelineItem(
                            time: '14:15',
                            title: 'Probable cause found',
                            sub: 'AI · moderate confidence',
                            dotColor: colors.accent,
                            isLast: false,
                            colors: colors,
                          ),
                          _buildTimelineItem(
                            time: '14:24',
                            title: 'Rollback approved',
                            sub: 'Alex Morgan',
                            dotColor: colors.warning,
                            isLast: false,
                            colors: colors,
                          ),
                          _buildTimelineItem(
                            time: '14:33',
                            title: 'Recovery verified',
                            sub: 'Health checks passed',
                            dotColor: colors.ok,
                            isLast: true,
                            colors: colors,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Root cause Card
                    _buildSectionCard(
                      title: 'Root cause',
                      body: 'DB_POOL_TIMEOUT lowered from 1000 ms to 500 ms in PR #214, without a load test.',
                      colors: colors,
                    ),
                    const SizedBox(height: 14),

                    // Evidence Card
                    _buildSectionCard(
                      title: 'Evidence',
                      body: '212 “connection timeout” log lines (Loki) · error rate 0.3% → 12.4% at 14:07 (Prometheus) · v2.8.1 deployed 2 min earlier (GitHub)',
                      colors: colors,
                    ),
                    const SizedBox(height: 14),

                    // Action and result Card
                    _buildSectionCard(
                      title: 'Action and result',
                      body: 'Rollback playbook to v2.8.0. Error rate 0.4%, P95 190 ms.',
                      colors: colors,
                    ),
                    const SizedBox(height: 14),

                    // Follow-ups Card
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
                          Text(
                            'Follow-ups',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.52,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• Add a load test for pool settings\n• Revert the timeout in PR #215',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Shared notification banner
                    if (_shared) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.infoSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Shared to Slack #payments-oncall and saved to Supabase.',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Buttons or Resolved Card
                    if (!_resolved) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _shared = true);
                                },
                                icon: Icon(Icons.send_outlined, size: 18, color: colors.text),
                                label: Text(
                                  'Share',
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
                                onPressed: () {
                                  setState(() => _resolved = true);
                                },
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text(
                                  'Resolve incident',
                                  style: TextStyle(
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
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.successSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INC-1042 resolved',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Moved to incident history. The team was notified.',
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/dashboard',
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.accent,
                                  foregroundColor: colors.onAccent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Back to overview',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactCard({
    required String label,
    required String value,
    required dynamic colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String body,
    required dynamic colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.52,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String time,
    required String title,
    required String sub,
    required Color dotColor,
    required bool isLast,
    required dynamic colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: colors.border,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: colors.text),
                    children: [
                      TextSpan(
                        text: '$time  ',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'JetBrains Mono',
                          color: colors.muted,
                        ),
                      ),
                      TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(fontSize: 13, color: colors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepper(BuildContext context, {required int activeStage}) {
    final colors = context.colors;
    final stages = ['Detect', 'Investigate', 'Cause', 'Approve', 'Recover', 'Report'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: List.generate(stages.length, (index) {
          final isCompleted = index < activeStage;
          final isActive = index == activeStage;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index == 0
                            ? Colors.transparent
                            : (index <= activeStage ? colors.ok : colors.border),
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? colors.ok
                            : (isActive ? colors.accentSoft : colors.card),
                        shape: BoxShape.circle,
                        border: isCompleted
                            ? null
                            : Border.all(
                                color: isActive ? colors.accent : colors.border,
                                width: 2,
                              ),
                      ),
                      alignment: Alignment.center,
                      child: isCompleted
                          ? Icon(Icons.check, size: 13, color: colors.card)
                          : (isActive
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index == stages.length - 1
                            ? Colors.transparent
                            : (index < activeStage ? colors.ok : colors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  stages[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? colors.accent
                        : (isCompleted ? colors.text : colors.muted),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
