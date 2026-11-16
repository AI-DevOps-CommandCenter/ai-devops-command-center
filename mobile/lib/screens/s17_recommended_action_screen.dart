import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import 's19_execution_progress_screen.dart';
import 's23_developer_assistant_screen.dart';
import 's31_reject_action_screen.dart';

class S17RecommendedActionScreen extends StatefulWidget {
  const S17RecommendedActionScreen({super.key});

  @override
  State<S17RecommendedActionScreen> createState() => _S17RecommendedActionScreenState();
}

class _S17RecommendedActionScreenState extends State<S17RecommendedActionScreen> {
  bool _check1 = false;
  bool _check2 = false;

  bool get _ready => _check1 && _check2;

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
                          'Recommended action',
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
                    // 6-Stage Stepper: Detect, Investigate, Cause, Approve (active), Recover, Report
                    _buildStepper(context, activeStage: 3),
                    const SizedBox(height: 14),

                    // Main Action Card
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
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.accentSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.history_rounded, size: 22, color: colors.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Roll back deployment',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: colors.text,
                                      ),
                                    ),
                                    Text(
                                      'Playbook 2 of 4 · reviewed by admins',
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
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.badgeRedBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'High impact',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    color: colors.critical,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.badgeAmberBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Approval required',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    color: colors.warning,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.badgeGreenBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Reversible',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    color: colors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildDetailRow(
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
                          _buildDetailRow(
                            label: 'Version',
                            valueWidget: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.text,
                                ),
                                children: [
                                  const TextSpan(text: 'v2.8.1'),
                                  TextSpan(text: ' → ', style: TextStyle(color: colors.muted, fontFamily: 'sans-serif')),
                                  const TextSpan(text: 'v2.8.0'),
                                ],
                              ),
                            ),
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            label: 'v2.8.0 health',
                            valueWidget: Text(
                              'Stable for 22 h before deploy',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            label: 'Expected result',
                            valueWidget: Text(
                              'Errors below 1% within 5 min',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            label: 'Side effect',
                            valueWidget: Text(
                              '~30 s of failed requests',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                            colors: colors,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Other playbooks
                    Text(
                      'Other playbooks',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),

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
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, height: 1.5, color: colors.muted),
                              children: [
                                TextSpan(
                                  text: 'Restart service',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.text),
                                ),
                                const TextSpan(text: ': would not fix the timeout setting.\n'),
                                TextSpan(
                                  text: 'Scale service',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.text),
                                ),
                                const TextSpan(text: ': more pods still use the 500 ms timeout.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Your approval
                    Text(
                      'Your approval',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Checkbox 1
                    InkWell(
                      onTap: () => setState(() => _check1 = !_check1),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _check1 ? colors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _check1 ? colors.accent : colors.border,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _check1
                                  ? Icon(Icons.check, size: 14, color: colors.onAccent)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'I verified the health of v2.8.0 before approving.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Checkbox 2
                    InkWell(
                      onTap: () => setState(() => _check2 = !_check2),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _check2 ? colors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _check2 ? colors.accent : colors.border,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _check2
                                  ? Icon(Icons.check, size: 14, color: colors.onAccent)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'I accept ~30 s of failed requests during the rollback.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Approve Button
                    if (_ready)
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const S19ExecutionProgressScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text(
                            'Approve and run rollback',
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
                      )
                    else
                      Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Confirm both checks to approve',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.muted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Action buttons: Reject / Ask assistant
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
                                    builder: (context) => const S31RejectActionScreen(),
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
                                'Reject',
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
                                    builder: (context) => const S23DeveloperAssistantScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.auto_awesome, size: 18, color: colors.text),
                              label: Text(
                                'Ask assistant',
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
                    const SizedBox(height: 12),

                    // Footer
                    Text(
                      'Your name and the time are saved to the audit log.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.muted,
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

  Widget _buildDetailRow({
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
