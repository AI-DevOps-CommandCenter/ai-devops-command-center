import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 's09_logs_explorer_screen.dart';
import 's16_remediation_playbooks_screen.dart';

class S32Inc1041Screen extends StatelessWidget {
  const S32Inc1041Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: INC-1041 · Queue backlog growing
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
                          'INC-1041',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Queue backlog growing',
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

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Badges: Warning · Monitoring · Production
                  Wrap(
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.warning.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 13, color: colors.warning),
                            const SizedBox(width: 4),
                            Text(
                              'Warning',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.warning,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.info.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Monitoring',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.info,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.cardSecondary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Production',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 6-stage Stepper (active: Investigate)
                  Container(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        _buildStepItem(
                            title: 'Detect',
                            state: _StepState.done,
                            colors: colors),
                        _buildStepItem(
                            connector: true,
                            title: 'Investigate',
                            state: _StepState.active,
                            colors: colors),
                        _buildStepItem(
                            connector: true,
                            title: 'Cause',
                            state: _StepState.todo,
                            colors: colors),
                        _buildStepItem(
                            connector: true,
                            title: 'Approve',
                            state: _StepState.todo,
                            colors: colors),
                        _buildStepItem(
                            connector: true,
                            title: 'Recover',
                            state: _StepState.todo,
                            colors: colors),
                        _buildStepItem(
                            connector: true,
                            title: 'Report',
                            state: _StepState.todo,
                            colors: colors),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Metadata Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        _buildMetaRow('Service', 'orders-worker', colors,
                            isMono: true),
                        const SizedBox(height: 10),
                        _buildMetaRow(
                            'Detected', '13:40 · by Prometheus alert', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('Owner', 'Priya Silva', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow(
                            'Backlog', '4,210 jobs · +18%/h', colors),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Timeline Header
                  Text(
                    'TIMELINE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
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
                      children: [
                        _buildTimelineEvent(
                          time: '13:40',
                          title: 'Alert: backlog above 3,000',
                          sub: 'Prometheus',
                          dotColor: colors.warning,
                          isLast: false,
                          colors: colors,
                        ),
                        _buildTimelineEvent(
                          time: '13:41',
                          title: 'AI investigation finished',
                          sub: 'No recent deploy · traffic +35%',
                          dotColor: colors.accent,
                          isLast: false,
                          colors: colors,
                        ),
                        _buildTimelineEvent(
                          time: '13:45',
                          title: 'Set to monitoring',
                          sub: 'Priya Silva',
                          dotColor: colors.info,
                          isLast: true,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // AI Recommendation Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.accent.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 18, color: colors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  fontSize: 14,
                                  color: colors.text,
                                  height: 1.45),
                              children: const [
                                TextSpan(
                                    text:
                                        'Likely cause: more orders than usual. Recommended: '),
                                TextSpan(
                                  text: 'Scale service',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                    text:
                                        ' to 6 replicas (low impact, runs without approval).'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons: Logs / Scale service
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const S09LogsExplorerScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.card,
                              foregroundColor: colors.text,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colors.border),
                              ),
                            ),
                            child: const Text(
                              'Logs',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const S16RemediationPlaybooksScreen(),
                                ),
                              );
                            },
                            icon: Icon(Icons.scale_outlined,
                                size: 18, color: colors.onAccent),
                            label: Text(
                              'Scale service',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.onAccent,
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
    );
  }

  Widget _buildStepItem({
    required String title,
    required _StepState state,
    required dynamic colors,
    bool connector = false,
  }) {
    Color circleBg;
    Color circleBorder;
    Widget? icon;
    Color textColor;
    FontWeight fontWeight;

    switch (state) {
      case _StepState.done:
        circleBg = colors.ok;
        circleBorder = colors.ok;
        icon = const Icon(Icons.check, size: 13, color: Colors.white);
        textColor = colors.text;
        fontWeight = FontWeight.w500;
        break;
      case _StepState.active:
        circleBg = colors.accent.withOpacity(0.16);
        circleBorder = colors.accent;
        icon = Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: colors.accent,
            shape: BoxShape.circle,
          ),
        );
        textColor = colors.accent;
        fontWeight = FontWeight.w600;
        break;
      case _StepState.todo:
        circleBg = Colors.transparent;
        circleBorder = colors.border;
        icon = null;
        textColor = colors.muted;
        fontWeight = FontWeight.w500;
        break;
    }

    // Line from the previous circle's centre to this circle's centre
    final lineColor = state == _StepState.todo ? colors.border : colors.ok;

    return Expanded(
      child: LayoutBuilder(
        builder: (context, box) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              if (connector)
                Positioned(
                  top: 10,
                  left: -box.maxWidth / 2,
                  width: box.maxWidth,
                  height: 2,
                  child: Container(color: lineColor),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Card-coloured backing so the line does not show through
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: circleBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: circleBorder, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: icon,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 14,
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      child: Text(
                        title,
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: fontWeight,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, dynamic colors,
      {bool isMono = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: colors.muted),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: isMono ? 'JetBrains Mono' : null,
            fontSize: isMono ? 12.5 : 14,
            fontWeight: FontWeight.w500,
            color: colors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineEvent({
    required String time,
    required String title,
    required String sub,
    required Color dotColor,
    required bool isLast,
    required dynamic colors,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colors.border,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
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
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
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
      ),
    );
  }
}

enum _StepState { done, active, todo }
