import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S10MetricsScreen extends StatefulWidget {
  const S10MetricsScreen({super.key});

  @override
  State<S10MetricsScreen> createState() => _S10MetricsScreenState();
}

class _S10MetricsScreenState extends State<S10MetricsScreen> {
  String _selectedRange = '1h';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Monitor · payments-api · Prometheus
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitor',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.52,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'payments-api · Prometheus',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/services');
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
                      alignment: Alignment.center,
                      child: Icon(Icons.dns_outlined, size: 20, color: colors.text),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Sub-nav tabs: Services, Logs, Metrics (active)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.cardSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/services');
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              child: Text(
                                'Services',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/logs');
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              child: Text(
                                'Logs',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.18),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              'Metrics',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Time range selector: 15m, 1h, 6h, 24h
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.cardSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: ['15m', '1h', '6h', '24h'].map((r) {
                        final isSelected = _selectedRange == r;
                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedRange = r;
                              });
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              height: 36,
                              alignment: Alignment.center,
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: colors.card,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromRGBO(0, 0, 0, 0.18),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    )
                                  : null,
                              child: Text(
                                r,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? colors.text : colors.muted,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Error rate card
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Error rate',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              '12.4%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colors.critical,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _ErrorRateChartPainter(
                              lineColor: colors.critical,
                              areaColor: colors.critical.withOpacity(0.14),
                              targetColor: colors.ok,
                              deployColor: colors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('13:45',
                                style: TextStyle(fontSize: 12, color: colors.muted)),
                            Text('▾ deploy 14:05',
                                style: TextStyle(fontSize: 12, color: colors.muted)),
                            Text('14:45',
                                style: TextStyle(fontSize: 12, color: colors.muted)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dashed green line: 1% target',
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // P95 latency card
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'P95 latency',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              '2.4 s',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _LatencyChartPainter(
                              lineColor: colors.warning,
                              areaColor: colors.warning.withOpacity(0.14),
                              targetColor: colors.ok,
                              deployColor: colors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('13:45',
                                style: TextStyle(fontSize: 12, color: colors.muted)),
                            Text('▾ deploy 14:05',
                                style: TextStyle(fontSize: 12, color: colors.muted)),
                            Text('14:45',
                                style: TextStyle(fontSize: 12, color: colors.muted)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dashed green line: 300 ms target',
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2-column CPU & Memory row
                  Row(
                    children: [
                      Expanded(
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
                              Text('CPU',
                                  style:
                                      TextStyle(fontSize: 13, color: colors.muted)),
                              const SizedBox(height: 2),
                              Text(
                                '71%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 36,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: _MiniSparklinePainter(
                                    color: colors.info,
                                    points: const [
                                      Offset(2.0, 33.0),
                                      Offset(19.0, 30.1),
                                      Offset(36.0, 31.1),
                                      Offset(53.0, 25.3),
                                      Offset(70.0, 20.4),
                                      Offset(87.0, 12.7),
                                      Offset(104.0, 7.9),
                                      Offset(121.0, 6.0),
                                      Offset(138.0, 5.0),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
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
                              Text('Memory',
                                  style:
                                      TextStyle(fontSize: 13, color: colors.muted)),
                              const SizedBox(height: 2),
                              Text(
                                '64%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 36,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: _MiniSparklinePainter(
                                    color: colors.info,
                                    points: const [
                                      Offset(2.0, 33.0),
                                      Offset(19.0, 28.3),
                                      Offset(36.0, 23.7),
                                      Offset(53.0, 23.7),
                                      Offset(70.0, 19.0),
                                      Offset(87.0, 14.3),
                                      Offset(104.0, 9.7),
                                      Offset(121.0, 5.0),
                                      Offset(138.0, 5.0),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Nav
            const AppBottomNav(currentIndex: 2),
          ],
        ),
      ),
    );
  }
}

class _ErrorRateChartPainter extends CustomPainter {
  final Color lineColor;
  final Color areaColor;
  final Color targetColor;
  final Color deployColor;

  _ErrorRateChartPainter({
    required this.lineColor,
    required this.areaColor,
    required this.targetColor,
    required this.deployColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rawPoints = [
      const Offset(0.0, 84.1),
      const Offset(26.7, 84.1),
      const Offset(53.3, 83.4),
      const Offset(80.0, 84.1),
      const Offset(106.7, 84.1),
      const Offset(133.3, 83.4),
      const Offset(160.0, 47.3),
      const Offset(186.7, 15.0),
      const Offset(213.3, 6.0),
      const Offset(240.0, 7.9),
      const Offset(266.7, 6.0),
      const Offset(293.3, 7.3),
      const Offset(320.0, 6.0),
    ];

    final sx = size.width / 320.0;
    final sy = size.height / 90.0;

    // Fill area
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

    // Target line y = 79.5 (dashed)
    final targetY = 79.5 * sy;
    final targetPaint = Paint()
      ..color = targetColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, Offset(0, targetY), Offset(size.width, targetY), 4, 4,
        targetPaint);

    // Deploy line x = 106.7 (dashed)
    final deployX = 106.7 * sx;
    final deployPaint = Paint()
      ..color = deployColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
        canvas, Offset(deployX, 0), Offset(deployX, size.height), 3, 3, deployPaint);

    // Polyline
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

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, double dashWidth,
      double dashSpace, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = (dx * dx + dy * dy) > 0 ? (Offset(dx, dy).distance) : 0;
    if (distance == 0) return;
    final unitX = dx / distance;
    final unitY = dy / distance;
    double current = 0;
    while (current < distance) {
      final startX = p1.dx + unitX * current;
      final startY = p1.dy + unitY * current;
      final len = (current + dashWidth < distance) ? dashWidth : distance - current;
      final endX = startX + unitX * len;
      final endY = startY + unitY * len;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      current += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LatencyChartPainter extends CustomPainter {
  final Color lineColor;
  final Color areaColor;
  final Color targetColor;
  final Color deployColor;

  _LatencyChartPainter({
    required this.lineColor,
    required this.areaColor,
    required this.targetColor,
    required this.deployColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rawPoints = [
      const Offset(0.0, 80.0),
      const Offset(26.7, 80.2),
      const Offset(53.3, 79.7),
      const Offset(80.0, 79.8),
      const Offset(106.7, 80.0),
      const Offset(133.3, 79.3),
      const Offset(160.0, 56.0),
      const Offset(186.7, 26.0),
      const Offset(213.3, 9.3),
      const Offset(240.0, 6.0),
      const Offset(266.7, 7.7),
      const Offset(293.3, 6.0),
      const Offset(320.0, 6.0),
    ];

    final sx = size.width / 320.0;
    final sy = size.height / 90.0;

    // Fill area
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

    // Target line y = 76.0 (dashed)
    final targetY = 76.0 * sy;
    final targetPaint = Paint()
      ..color = targetColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, Offset(0, targetY), Offset(size.width, targetY), 4, 4,
        targetPaint);

    // Deploy line x = 106.7 (dashed)
    final deployX = 106.7 * sx;
    final deployPaint = Paint()
      ..color = deployColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
        canvas, Offset(deployX, 0), Offset(deployX, size.height), 3, 3, deployPaint);

    // Polyline
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

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, double dashWidth,
      double dashSpace, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = (dx * dx + dy * dy) > 0 ? (Offset(dx, dy).distance) : 0;
    if (distance == 0) return;
    final unitX = dx / distance;
    final unitY = dy / distance;
    double current = 0;
    while (current < distance) {
      final startX = p1.dx + unitX * current;
      final startY = p1.dy + unitY * current;
      final len = (current + dashWidth < distance) ? dashWidth : distance - current;
      final endX = startX + unitX * len;
      final endY = startY + unitY * len;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      current += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniSparklinePainter extends CustomPainter {
  final Color color;
  final List<Offset> points;

  _MiniSparklinePainter({required this.color, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final sx = size.width / 140.0;
    final sy = size.height / 36.0;

    final path = Path();
    path.moveTo(points.first.dx * sx, points.first.dy * sy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * sx, points[i].dy * sy);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
