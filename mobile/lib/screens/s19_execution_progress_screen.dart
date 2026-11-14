import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import 's21_postmortem_report_screen.dart';

class S19ExecutionProgressScreen extends StatelessWidget {
  const S19ExecutionProgressScreen({super.key});

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
                          'INC-1042 · payments-api · rollback',
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
                    // Stepper: Detect(ok), Investigate(ok), Cause(ok), Approve(ok), Recover(active), Report(idle)
                    _buildStepper(context, activeStage: 4),
                    const SizedBox(height: 14),

                    // Green Banner: Service recovered
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.successSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 26, color: colors.ok),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Service recovered',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colors.text,
                                  ),
                                ),
                                Text(
                                  'Verified at 14:33 after a 5-minute check window',
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
                    const SizedBox(height: 14),

                    // Section: Before and after
                    Text(
                      'Before and after',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 3-column Before and after cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildBeforeAfterCard(
                            label: 'Error rate',
                            before: '12.4%',
                            after: '0.4%',
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBeforeAfterCard(
                            label: 'P95',
                            before: '2.4 s',
                            after: '190 ms',
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBeforeAfterCard(
                            label: 'Timeouts',
                            before: '212',
                            after: '0',
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section: Steps
                    Text(
                      'Steps',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 5 Step Cards
                    _buildStepCard(
                      title: 'Approved',
                      time: '14:24',
                      desc: 'by Alex Morgan',
                      colors: colors,
                    ),
                    const SizedBox(height: 8),

                    _buildStepCard(
                      title: 'Deploy v2.8.0',
                      time: '14:25',
                      desc: 'GitHub Actions · pipeline #320',
                      colors: colors,
                    ),
                    const SizedBox(height: 8),

                    _buildStepCard(
                      title: 'Restart pods',
                      time: '14:26',
                      desc: '3 of 3 pods healthy',
                      colors: colors,
                    ),
                    const SizedBox(height: 8),

                    _buildStepCard(
                      title: 'Health checks',
                      time: '14:27',
                      desc: 'Error rate below 1% · P95 below 300 ms',
                      colors: colors,
                    ),
                    const SizedBox(height: 8),

                    _buildStepCard(
                      title: 'Verify for 5 minutes',
                      time: '14:33',
                      desc: 'No new connection timeouts',
                      colors: colors,
                    ),
                    const SizedBox(height: 14),

                    // Button: Open postmortem
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const S21PostmortemReportScreen(),
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
                          'Open postmortem',
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

  Widget _buildBeforeAfterCard({
    required String label,
    required String before,
    required String after,
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
            before,
            style: TextStyle(
              fontSize: 13,
              color: colors.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text(
            after,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: colors.ok,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required String time,
    required String desc,
    required dynamic colors,
  }) {
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
            child: Icon(Icons.check, size: 16, color: colors.ok),
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
                        fontSize: 12.5,
                        fontFamily: 'JetBrains Mono',
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
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
