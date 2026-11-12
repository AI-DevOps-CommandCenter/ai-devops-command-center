import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 's24_pull_request_summary_screen.dart';

class S14DeploymentDetailsScreen extends StatelessWidget {
  const S14DeploymentDetailsScreen({super.key});

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
                          'v2.8.1',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'payments-api · Production',
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
                      color: colors.warning.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Rolled back',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.warning,
                        height: 1.5,
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
                  // Alert Banner: Linked to INC-1042
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.warning.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 22, color: colors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Linked to INC-1042',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Errors started 2 minutes after this deploy. Rolled back to v2.8.0 at 14:25.',
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
                        _buildMetaRow('Deployed', 'Today 14:05', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('By', 'Alex Morgan', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('Pipeline', '#318 · passed · 2m 05s', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('Commit', 'a91f3c2', colors, isMono: true),
                        const SizedBox(height: 10),
                        _buildMetaRow(
                            'Pull request', '#214 Tune DB pool settings', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('Replaced', 'v2.8.0', colors),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Config changes Header
                  Text(
                    'CONFIG CHANGES',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Config changes Diff Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.codeBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '- DB_POOL_TIMEOUT=1000',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12.5,
                            height: 1.7,
                            color: colors.critical,
                          ),
                        ),
                        Text(
                          '+ DB_POOL_TIMEOUT=500',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12.5,
                            height: 1.7,
                            color: colors.ok,
                          ),
                        ),
                        Text(
                          '+ DB_RETRIES=3',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12.5,
                            height: 1.7,
                            color: colors.ok,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Health after deploy Header
                  Text(
                    'HEALTH AFTER DEPLOY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Health after deploy Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 52,
                          child: CustomPaint(
                            painter: _DeployHealthChartPainter(
                              lineColor: colors.critical,
                              areaColor: colors.critical.withOpacity(0.14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('14:00',
                                style:
                                    TextStyle(fontSize: 12, color: colors.muted)),
                            Text('deploy 14:05',
                                style:
                                    TextStyle(fontSize: 12, color: colors.muted)),
                            Text('rollback 14:25',
                                style:
                                    TextStyle(fontSize: 12, color: colors.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons: View PR #214 / Incident
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const S24PullRequestSummaryScreen(),
                                ),
                              );
                            },
                            icon: Icon(Icons.call_split,
                                size: 18, color: colors.text),
                            label: Text(
                              'View PR #214',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.card,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colors.border),
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
                              Navigator.pushNamed(context, '/incident-details');
                            },
                            icon: Icon(Icons.warning_amber_rounded,
                                size: 18, color: colors.text),
                            label: Text(
                              'Incident',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.card,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colors.border),
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

            // Bottom Nav
            const AppBottomNav(currentIndex: 3),
          ],
        ),
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
}

class _DeployHealthChartPainter extends CustomPainter {
  final Color lineColor;
  final Color areaColor;

  _DeployHealthChartPainter({
    required this.lineColor,
    required this.areaColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rawPoints = [
      const Offset(0.0, 48.0),
      const Offset(25.0, 48.0),
      const Offset(50.0, 20.0),
      const Offset(100.0, 6.0),
      const Offset(150.0, 6.0),
      const Offset(200.0, 8.0),
      const Offset(225.0, 15.0),
      const Offset(250.0, 45.0),
      const Offset(300.0, 48.0),
    ];

    final sx = size.width / 300.0;
    final sy = size.height / 52.0;

    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (final p in rawPoints) {
      fillPath.lineTo(p.dx * sx, p.dy * sy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = areaColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path();
    linePath.moveTo(rawPoints.first.dx * sx, rawPoints.first.dy * sy);
    for (int i = 1; i < rawPoints.length; i++) {
      linePath.lineTo(rawPoints[i].dx * sx, rawPoints[i].dy * sy);
    }
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
