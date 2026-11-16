import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import 's07_root_cause_screen.dart';

class S06AiInvestigationProgressScreen extends StatelessWidget {
  const S06AiInvestigationProgressScreen({super.key});

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
                          'AI investigation',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'INC-1042 · payments-api',
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
                    // 6-Stage Stepper: Detect (done), Investigate (active), Cause, Approve, Recover, Report
                    _buildStepper(context, activeStage: 1),
                    const SizedBox(height: 14),

                    // Progress Header: AI INVESTIGATION / Started 14:13
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AI INVESTIGATION',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.52,
                            color: colors.muted,
                          ),
                        ),
                        Text(
                          'Started 14:13',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Progress Summary Card: 3 of 4 checks complete (75%)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '3 of 4 checks complete',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Correlating logs with recent commit',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '75%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Check 1: Collect logs (Done)
                    _buildCheckCard(
                      context,
                      title: 'Collect logs',
                      status: 'Done',
                      isDone: true,
                      description: '212 “connection timeout” errors since 14:07',
                      source: 'Source: Loki',
                    ),
                    const SizedBox(height: 10),

                    // Check 2: Check metrics (Done)
                    _buildCheckCard(
                      context,
                      title: 'Check metrics',
                      status: 'Done',
                      isDone: true,
                      description: 'Error rate and P95 latency jumped at 14:07',
                      source: 'Source: Prometheus',
                    ),
                    const SizedBox(height: 10),

                    // Check 3: Review deployments (Done)
                    _buildCheckCard(
                      context,
                      title: 'Review deployments',
                      status: 'Done',
                      isDone: true,
                      description: 'v2.8.1 went live at 14:05 · PR #214 changed the DB pool timeout',
                      source: 'Source: GitHub',
                    ),
                    const SizedBox(height: 10),

                    // Check 4: Correlate and explain (Running)
                    _buildCheckCard(
                      context,
                      title: 'Correlate and explain',
                      status: 'Running',
                      isDone: false,
                      description: 'Combining the three results into one probable cause',
                      source: 'Source: Groq via n8n',
                    ),
                    const SizedBox(height: 14),

                    // Guardrail Blue Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.info.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: colors.info, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'The AI only reads data and suggests. It can recommend one of 4 reviewed playbooks, but it cannot run anything on its own.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Primary Button: See root cause
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const S07RootCauseScreen(),
                            ),
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
                          'See root cause',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckCard(
    BuildContext context, {
    required String title,
    required String status,
    required bool isDone,
    required String description,
    required String source,
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
          if (isDone)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.badgeGreenBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.check, size: 16, color: colors.success),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.accentSoft, width: 3),
              ),
              alignment: Alignment.center,
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDone ? colors.badgeGreenBg : colors.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: isDone ? colors.success : colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  source,
                  style: TextStyle(
                    fontSize: 12,
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
          final title = stages[index];

          Color textColor = colors.muted;
          FontWeight fontWeight = FontWeight.w500;
          if (isActive) {
            textColor = colors.accent;
            fontWeight = FontWeight.w600;
          } else if (isCompleted) {
            textColor = colors.text;
          }

          return Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (index > 0)
                  Positioned(
                    top: 10,
                    right: 0,
                    left: -50,
                    child: Container(
                      height: 2,
                      color: isCompleted || isActive ? colors.success : colors.border,
                    ),
                  ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? colors.success
                            : isActive
                                ? colors.accentSoft
                                : colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted
                              ? colors.success
                              : isActive
                                  ? colors.accent
                                  : colors.border,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isCompleted
                          ? Icon(Icons.check, size: 13, color: colors.card)
                          : isActive
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: fontWeight,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
