import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import 's06_ai_investigation_progress_screen.dart';
import 's09_logs_explorer_screen.dart';
import 's10_metrics_screen.dart';
import 's14_deployment_details_screen.dart';

class S05IncidentDetailsScreen extends StatelessWidget {
  const S05IncidentDetailsScreen({super.key});

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
                          'INC-1042',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Elevated errors after deployment',
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
                    // Badges row: gap 8px
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.badgeRedBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 13, color: colors.critical),
                              const SizedBox(width: 4),
                              Text(
                                'Critical',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: colors.critical,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Investigating',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: colors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.surface2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Production',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: colors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 6-Stage Stepper: Detect (done), Investigate (active), Cause, Approve, Recover, Report
                    _buildStepper(context, activeStage: 1),
                    const SizedBox(height: 14),

                    // Metadata Card: Service, Detected, Owner, Suspected change
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          _buildMetaRow(
                            label: 'Service',
                            valueWidget: Text(
                              'payments-api',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'JetBrains Mono',
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildMetaRow(
                            label: 'Detected',
                            valueWidget: Text(
                              '14:12 · by Prometheus alert',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildMetaRow(
                            label: 'Owner',
                            valueWidget: Text(
                              'Alex Morgan (on call)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildMetaRow(
                            label: 'Suspected change',
                            valueWidget: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colors.text,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'v2.8.1',
                                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                                  ),
                                  const TextSpan(text: ' · PR #214'),
                                ],
                              ),
                            ),
                            colors: colors,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Metrics grid: Error rate (0.3% -> 12.4%) & P95 latency (180 ms -> 2.4 s)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.badgeRedBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Error rate',
                                  style: TextStyle(fontSize: 13, color: colors.muted),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 15),
                                    children: [
                                      TextSpan(
                                        text: '0.3%',
                                        style: TextStyle(color: colors.muted),
                                      ),
                                      TextSpan(
                                        text: ' → ',
                                        style: TextStyle(color: colors.muted),
                                      ),
                                      TextSpan(
                                        text: '12.4%',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: colors.critical,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.badgeRedBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'P95 latency',
                                  style: TextStyle(fontSize: 13, color: colors.muted),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 15),
                                    children: [
                                      TextSpan(
                                        text: '180 ms',
                                        style: TextStyle(color: colors.muted),
                                      ),
                                      TextSpan(
                                        text: ' → ',
                                        style: TextStyle(color: colors.muted),
                                      ),
                                      TextSpan(
                                        text: '2.4 s',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: colors.critical,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Timeline Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TIMELINE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.52,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

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
                          _buildTimelineRow(
                            time: '14:05',
                            title: 'v2.8.1 deployed',
                            subtitle: 'Pipeline #318 passed · GitHub Actions',
                            dotColor: colors.info,
                            hasLineAfter: true,
                            colors: colors,
                          ),
                          _buildTimelineRow(
                            time: '14:07',
                            title: 'First DB connection timeouts',
                            subtitle: 'Loki · payments-api pods',
                            dotColor: colors.warning,
                            hasLineAfter: true,
                            colors: colors,
                          ),
                          _buildTimelineRow(
                            time: '14:12',
                            title: 'Alert: error rate above 5%',
                            subtitle: 'Prometheus · notified Alex Morgan',
                            dotColor: colors.critical,
                            hasLineAfter: true,
                            colors: colors,
                          ),
                          _buildTimelineRow(
                            time: '14:13',
                            title: 'AI investigation started',
                            subtitle: 'n8n workflow · logs, metrics, deployments',
                            dotColor: colors.accent,
                            hasLineAfter: false,
                            colors: colors,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Explore Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EXPLORE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.52,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 3 Explore Buttons: Logs, Metrics, Deploy
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const S09LogsExplorerScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.border),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.terminal, size: 20, color: colors.text),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Logs',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const S10MetricsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.border),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.show_chart, size: 20, color: colors.text),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Metrics',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const S14DeploymentDetailsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.border),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.account_tree_outlined, size: 20, color: colors.text),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Deploy',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Primary Button: View AI investigation
                    SizedBox(
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
                          'View AI investigation',
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow({
    required String label,
    required Widget valueWidget,
    required AppColorScheme colors,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: colors.muted),
        ),
        valueWidget,
      ],
    );
  }

  Widget _buildTimelineRow({
    required String time,
    required String title,
    required String subtitle,
    required Color dotColor,
    required bool hasLineAfter,
    required AppColorScheme colors,
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
            if (hasLineAfter)
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
            padding: EdgeInsets.only(bottom: hasLineAfter ? 14.0 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: colors.text),
                    children: [
                      TextSpan(
                        text: time,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'JetBrains Mono',
                          color: colors.muted,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
                // Connecting bar
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
