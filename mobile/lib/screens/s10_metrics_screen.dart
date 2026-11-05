import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
    final double factor = _selectedRange == '1h' ? 1.0 : (_selectedRange == '6h' ? 0.8 : 0.6);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.text, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Metrics',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'payments-api',
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

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Range Selector Tabs (1h, 6h, 24h)
                    Row(
                      children: ['1h', '6h', '24h'].map((range) {
                        final isSelected = _selectedRange == range;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedRange = range;
                              });
                            },
                            borderRadius: BorderRadius.circular(99),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? colors.teal : Colors.transparent,
                                borderRadius: BorderRadius.circular(99),
                                border: isSelected ? null : Border.all(color: colors.border),
                              ),
                              child: Text(
                                range,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? (colors.isDark ? const Color(0xFF06202A) : Colors.white)
                                      : colors.muted,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Chart 1: CPU (%)
                    _buildChartCard(
                      colors: colors,
                      title: 'CPU',
                      unit: '%',
                      points: [40, 42, 41, 55, 70, 71].map((x) => x * factor).toList(),
                      color: colors.teal,
                      currentValue: '${(71 * factor).toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 12),

                    // Chart 2: Memory (%)
                    _buildChartCard(
                      colors: colors,
                      title: 'Memory',
                      unit: '%',
                      points: [55, 56, 58, 60, 63, 64].map((x) => x * factor).toList(),
                      color: colors.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                      currentValue: '${(64 * factor).toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 12),

                    // Chart 3: Error rate (%)
                    _buildChartCard(
                      colors: colors,
                      title: 'Error rate',
                      unit: '%',
                      points: [0.3, 0.3, 0.3, 8.0, 12.0, 12.4].map((x) => x * factor).toList(),
                      color: colors.red,
                      currentValue: '${(12.4 * factor).toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 12),

                    // Chart 4: P95 latency (ms)
                    _buildChartCard(
                      colors: colors,
                      title: 'P95 latency',
                      unit: 'ms',
                      points: [180, 185, 190, 1600, 2300, 2400].map((x) => x * factor).toList(),
                      color: colors.amber,
                      currentValue: '${(2400 * factor).toStringAsFixed(0)} ms',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required AppColorScheme colors,
    required String title,
    required String unit,
    required List<double> points,
    required Color color,
    required String currentValue,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: colors.isDark ? Colors.black.withOpacity(0.3) : const Color.fromRGBO(15, 27, 51, 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Title & Unit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custom Chart Canvas with Polyline and Amber Marker
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: _MetricChartPainter(
                points: points,
                lineColor: color,
                markerColor: colors.amber,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deploy v2.8.1 marker (amber)',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.muted,
                ),
              ),
              Text(
                'Now: $currentValue',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChartPainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final Color markerColor;

  _MetricChartPainter({
    required this.points,
    required this.lineColor,
    required this.markerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double maxVal = (points.reduce((a, b) => a > b ? a : b) * 1.15).clamp(1.0, double.infinity);
    final double stepX = size.width / (points.length - 1);

    // Draw dashed amber marker in center (deployment point)
    final Paint markerPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double centerX = size.width * 0.5;
    const double dashHeight = 4.0;
    const double dashSpace = 3.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(centerX, startY),
        Offset(centerX, (startY + dashHeight).clamp(0, size.height)),
        markerPaint,
      );
      startY += dashHeight + dashSpace;
    }

    // Draw metric polyline
    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      final double x = i * stepX;
      final double y = size.height - (points[i] / maxVal * size.height).clamp(0.0, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.markerColor != markerColor;
  }
}
