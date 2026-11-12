import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';

class S03OverviewDashboardScreen extends StatelessWidget {
  const S03OverviewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Overview + Bell (44x44) + Avatar (44x44)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BrandLogo(size: 34),
                            const SizedBox(width: 10),
                            Text(
                              'Overview',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.52,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Production · Good afternoon, Alex',
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Notifications Bell button (44x44)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/notifications');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              LucideIcon(LucideIconData.bell, size: 20, color: colors.text),
                              Positioned(
                                top: 9,
                                right: 10,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colors.critical,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colors.card, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Profile AM button (44x44)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/profile');
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'AM',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // 1. INC-1042 Critical Hero Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top badges row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.criticalSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LucideIcon(LucideIconData.alertTriangle, size: 13, color: colors.critical, strokeWidth: 2),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Critical',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
                                color: colors.warningSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Awaiting approval',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.warning,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '19 min',
                              style: TextStyle(fontSize: 13, color: colors.muted),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Title & Subtitle
                        Text(
                          'INC-1042 · payments-api',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'JetBrains Mono',
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Elevated errors after deployment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Description
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 14, color: colors.muted),
                            children: [
                              const TextSpan(text: 'AI found a probable cause and recommends '),
                              TextSpan(
                                text: 'rolling back to v2.8.0',
                                style: TextStyle(fontWeight: FontWeight.w700, color: colors.text),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Actions buttons row
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/incident-details');
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: colors.card,
                                    side: BorderSide(color: colors.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Details',
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
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/recommended-action');
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
                                    'Review action',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
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

                  const SizedBox(height: 14),

                  // 2. Incidents by severity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INCIDENTS BY SEVERITY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.52,
                          color: colors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/incidents');
                        },
                        child: Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 3-column severity cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSeverityCard(
                          context,
                          title: 'Critical',
                          dotColor: colors.critical,
                          count: '1',
                          sub: 'open',
                          onTap: () {
                            Navigator.pushNamed(context, '/incidents');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSeverityCard(
                          context,
                          title: 'Warning',
                          dotColor: colors.warning,
                          count: '2',
                          sub: 'open',
                          onTap: () {
                            Navigator.pushNamed(context, '/incidents');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSeverityCard(
                          context,
                          title: 'Resolved',
                          dotColor: colors.ok,
                          count: '3',
                          sub: 'last 7 days',
                          onTap: () {
                            Navigator.pushNamed(context, '/incidents');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 2. Service health
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SERVICE HEALTH',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.52,
                          color: colors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/services');
                        },
                        child: Text(
                          '6 services',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Service health bar card
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/services');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 8,
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Container(color: colors.ok)),
                                  const SizedBox(width: 2),
                                  Expanded(flex: 2, child: Container(color: colors.warning)),
                                  const SizedBox(width: 2),
                                  Expanded(flex: 1, child: Container(color: colors.critical)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '3 healthy  2 warning  1 degraded',
                              style: TextStyle(fontSize: 13, color: colors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. PAYMENTS-API · LAST HOUR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PAYMENTS-API · LAST HOUR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.52,
                          color: colors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/metrics');
                        },
                        child: Text(
                          'Metrics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Row 1: Error rate & P95 latency
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Error rate',
                          value: '12.4%',
                          valueColor: colors.critical,
                          sub: 'Target below 1%',
                          points: const [
                            Offset(2.0, 33.0),
                            Offset(15.6, 33.0),
                            Offset(29.2, 32.8),
                            Offset(42.8, 33.0),
                            Offset(56.4, 33.0),
                            Offset(70.0, 26.8),
                            Offset(83.6, 15.2),
                            Offset(97.2, 8.2),
                            Offset(110.8, 5.0),
                            Offset(124.4, 5.7),
                            Offset(138.0, 5.0),
                          ],
                          strokeColor: colors.critical,
                          onTap: () {
                            Navigator.pushNamed(context, '/metrics');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'P95 latency',
                          value: '2.4 s',
                          valueColor: colors.critical,
                          sub: 'Target below 300 ms',
                          points: const [
                            Offset(2.0, 33.0),
                            Offset(15.6, 33.0),
                            Offset(29.2, 33.0),
                            Offset(42.8, 33.0),
                            Offset(56.4, 33.0),
                            Offset(70.0, 27.1),
                            Offset(83.6, 15.7),
                            Offset(97.2, 8.6),
                            Offset(110.8, 5.0),
                            Offset(124.4, 5.7),
                            Offset(138.0, 5.0),
                          ],
                          strokeColor: colors.critical,
                          onTap: () {
                            Navigator.pushNamed(context, '/metrics');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Row 2: CPU & Memory
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'CPU',
                          value: '71%',
                          valueColor: colors.warning,
                          sub: 'c5.xlarge · 4 vCPU',
                          points: const [
                            Offset(2.0, 33.0),
                            Offset(15.6, 30.1),
                            Offset(29.2, 31.1),
                            Offset(42.8, 25.3),
                            Offset(56.4, 20.4),
                            Offset(70.0, 12.7),
                            Offset(83.6, 7.9),
                            Offset(97.2, 6.0),
                            Offset(110.8, 5.0),
                            Offset(124.4, 6.0),
                            Offset(138.0, 5.0),
                          ],
                          strokeColor: colors.warning,
                          onTap: () {
                            Navigator.pushNamed(context, '/metrics');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Memory',
                          value: '64%',
                          valueColor: colors.info,
                          sub: '10.2 of 16 GB',
                          points: const [
                            Offset(2.0, 33.0),
                            Offset(15.6, 28.3),
                            Offset(29.2, 23.7),
                            Offset(42.8, 23.7),
                            Offset(56.4, 19.0),
                            Offset(70.0, 14.3),
                            Offset(83.6, 9.7),
                            Offset(97.2, 9.7),
                            Offset(110.8, 5.0),
                            Offset(124.4, 5.0),
                            Offset(138.0, 5.0),
                          ],
                          strokeColor: colors.info,
                          onTap: () {
                            Navigator.pushNamed(context, '/metrics');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Footer
                  Text(
                    'Group 33 ·',
                    textAlign: TextAlign.center,
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
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildSeverityCard(
    BuildContext context, {
    required String title,
    required Color dotColor,
    required String count,
    required String sub,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dotColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            Text(
              sub,
              style: TextStyle(fontSize: 12, color: colors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color valueColor,
    required String sub,
    required List<Offset> points,
    required Color strokeColor,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 13, color: colors.muted)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: valueColor)),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(points: points, color: strokeColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(sub, style: TextStyle(fontSize: 12, color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = points[i].dx * (size.width / 140.0);
      final y = points[i].dy * (size.height / 36.0);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => false;
}
