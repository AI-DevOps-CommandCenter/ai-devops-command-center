import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 's06_ai_investigation_progress_screen.dart';
import 's16_remediation_playbooks_screen.dart';
import 's09_logs_explorer_screen.dart';

class S44RollbackFailedScreen extends StatelessWidget {
  const S44RollbackFailedScreen({super.key});

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
                          'Recovery',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'INC-1042 \u00b7 payments-api \u00b7 rollback',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main scrollable area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // 6-stage Stepper (Recover failed, red)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        _buildStepItem(context, label: 'Detect', state: _StepState.done),
                        _buildStepConnector(context, isDone: true),
                        _buildStepItem(context, label: 'Investigate', state: _StepState.done),
                        _buildStepConnector(context, isDone: true),
                        _buildStepItem(context, label: 'Cause', state: _StepState.done),
                        _buildStepConnector(context, isDone: true),
                        _buildStepItem(context, label: 'Approve', state: _StepState.done),
                        _buildStepConnector(context, isDone: true),
                        _buildStepItem(context, label: 'Recover', state: _StepState.failed),
                        _buildStepConnector(context, isDone: false),
                        _buildStepItem(context, label: 'Report', state: _StepState.todo),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Red failure banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.criticalSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 22, color: colors.critical),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rollback did not recover the service',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Health checks still failing after 5 minutes. Nothing else was changed.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Timeline card 1: Approved 14:24 by Alex Morgan
                  _buildTimelineCard(
                    context,
                    title: 'Approved',
                    subtitle: 'by Alex Morgan',
                    time: '14:24',
                    isOk: true,
                  ),

                  const SizedBox(height: 14),

                  // Timeline card 2: Deploy v2.8.0 14:25 pipeline #320
                  _buildTimelineCard(
                    context,
                    title: 'Deploy v2.8.0',
                    subtitle: 'pipeline #320',
                    time: '14:25',
                    isOk: true,
                  ),

                  const SizedBox(height: 14),

                  // Timeline card 3: Health checks 14:32 (Failed with red border)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.critical),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colors.criticalSoft,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.close_rounded, size: 16, color: colors.critical),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Health checks',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: colors.text,
                                    ),
                                  ),
                                  Text(
                                    '14:32',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 12.5,
                                      color: colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Error rate still 9.8% \u00b7 DB primary not responding',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // What next card
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
                              'What next',
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
                          'The cause may be the database, not the deploy. The incident is escalated to the on-call team and the AI investigation is re-running with the new data.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Re-run investigation button (accent)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const S06AiInvestigationProgressScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text(
                        'Re-run investigation',
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

                  const SizedBox(height: 10),

                  // Other playbooks + Open logs row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const S16RemediationPlaybooksScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: colors.card,
                              side: BorderSide(color: colors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Other playbooks',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const S09LogsExplorerScreen(),
                                ),
                              );
                            },
                            icon: Icon(Icons.terminal_rounded, size: 18, color: colors.text),
                            label: Text(
                              'Open logs',
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(BuildContext context, {required String label, required _StepState state}) {
    final colors = context.colors;
    Widget icon;
    if (state == _StepState.done) {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Icon(Icons.check, size: 13, color: Colors.black),
      );
    } else if (state == _StepState.failed) {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: colors.card,
          shape: BoxShape.circle,
          border: Border.all(color: colors.critical, width: 2),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.close, size: 13, color: colors.critical),
      );
    } else {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.muted.withOpacity(0.4), width: 2),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          icon,
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: state == _StepState.todo ? colors.muted : colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(BuildContext context, {required bool isDone}) {
    final colors = context.colors;
    return Container(
      width: 14,
      height: 2,
      margin: const EdgeInsets.only(bottom: 22),
      color: isDone ? colors.success : colors.border,
    );
  }

  Widget _buildTimelineCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String time,
    required bool isOk,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.successSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.check, size: 16, color: colors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12.5,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, failed, todo }
