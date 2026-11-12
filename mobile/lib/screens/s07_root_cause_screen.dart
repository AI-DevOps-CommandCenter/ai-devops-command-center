import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import 's17_recommended_action_screen.dart';

class S07RootCauseScreen extends StatelessWidget {
  const S07RootCauseScreen({super.key});

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
                          'Root cause',
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
                    // 6-Stage Stepper: Detect, Investigate, Cause (active), Approve, Recover, Report
                    _buildStepper(context, activeStage: 2),
                    const SizedBox(height: 14),

                    // Probable Cause Card
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Probable cause',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.52,
                                  color: colors.muted,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.badgeAmberBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Moderate · 75%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    color: colors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'DB connection pool timeout was lowered to 500 ms in v2.8.1',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Timeouts started 2 minutes after the deploy and every failing request waited exactly 500 ms for a connection.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.surface2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Why not higher?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colors.text,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Timing and logs match, but no load test confirms it yet.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Evidence Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EVIDENCE',
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

                    // Evidence 1: Log errors (Loki)
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
                              Icon(Icons.terminal, size: 18, color: colors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Log errors',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.surface2,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Loki',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.codeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 12.5,
                                      height: 1.6,
                                      color: colors.text,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'ERROR ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colors.critical,
                                        ),
                                      ),
                                      const TextSpan(text: '14:07:11 connection timeout after '),
                                      WidgetSpan(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: colors.badgeAmberBg,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                          child: Text(
                                            '500ms',
                                            style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 12.5,
                                              color: colors.warning,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 12.5,
                                      height: 1.6,
                                      color: colors.text,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'WARN   ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colors.warning,
                                        ),
                                      ),
                                      const TextSpan(text: '14:07:14 pool exhausted (20/20)'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '212 matching lines · first at 14:07:11',
                            style: TextStyle(fontSize: 13, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Evidence 2: Metric change (Prometheus)
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
                              Icon(Icons.show_chart, size: 18, color: colors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Metric change',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.surface2,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Prometheus',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _MetricChangePainter(
                                lineColor: colors.critical,
                                dashColor: colors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('13:45', style: TextStyle(fontSize: 12, color: colors.muted)),
                              Text('deploy 14:05', style: TextStyle(fontSize: 12, color: colors.muted)),
                              Text('14:15', style: TextStyle(fontSize: 12, color: colors.muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Evidence 3: Deployment timing (GitHub)
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
                              Icon(Icons.account_tree_outlined, size: 18, color: colors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Deployment timing',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.surface2,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'GitHub',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, color: colors.text),
                              children: [
                                TextSpan(
                                  text: 'v2.8.1',
                                  style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                                ),
                                const TextSpan(text: ' · PR #214 “Tune DB pool settings”'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.codeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '- DB_POOL_TIMEOUT=1000',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 12.5,
                                    color: colors.critical,
                                  ),
                                ),
                                Text(
                                  '+ DB_POOL_TIMEOUT=500',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 12.5,
                                    color: colors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Card 4: Also checked
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
                            'Also checked',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Database overload: ruled out, DB CPU stayed at 38%.\nNetwork errors: ruled out, none in gateway logs.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Primary Button: Review recommended action
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const S17RecommendedActionScreen(),
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
                          'Review recommended action',
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

class _MetricChangePainter extends CustomPainter {
  final Color lineColor;
  final Color dashColor;

  _MetricChangePainter({required this.lineColor, required this.dashColor});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Vertical dash line at x = 120.4/300 * width
    final dashX = (120.4 / 300.0) * size.width;
    final dashPaint = Paint()
      ..color = dashColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(dashX, y), Offset(dashX, y + 3), dashPaint);
      y += 6;
    }

    // 2. Trend polyline points:
    // 2.0,49.0 31.6,49.0 61.2,48.6 90.8,49.0 120.4,49.0 150.0,48.6 179.6,28.3 209.2,10.1 238.8,5.0 268.4,6.1 298.0,5.0
    final points = [
      const Offset(2.0, 49.0),
      const Offset(31.6, 49.0),
      const Offset(61.2, 48.6),
      const Offset(90.8, 49.0),
      const Offset(120.4, 49.0),
      const Offset(150.0, 48.6),
      const Offset(179.6, 28.3),
      const Offset(209.2, 10.1),
      const Offset(238.8, 5.0),
      const Offset(268.4, 6.1),
      const Offset(298.0, 5.0),
    ];

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final px = (points[i].dx / 300.0) * size.width;
      final py = (points[i].dy / 52.0) * size.height;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
