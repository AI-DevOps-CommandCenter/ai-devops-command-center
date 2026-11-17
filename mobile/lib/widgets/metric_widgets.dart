import 'package:flutter/material.dart';
import '../models/service_metrics_model.dart';
import '../theme/app_colors.dart';

/// Shared metric widgets for S03 (dashboard), S10 (metrics) and S12 (service details).

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final List<double> values;
  final Color color;
  final VoidCallback? onTap;
  final double chartHeight;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.sub,
    required this.values,
    required this.color,
    this.onTap,
    this.chartHeight = 36,
  });

  @override
  Widget build(BuildContext context) {
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
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 6),
            SizedBox(
              height: chartHeight,
              width: double.infinity,
              child: values.length < 2
                  ? Center(child: Text('no data yet', style: TextStyle(fontSize: 11, color: colors.muted)))
                  : CustomPaint(painter: SparklinePainter(values: values, color: color)),
            ),
            const SizedBox(height: 6),
            Text(sub, style: TextStyle(fontSize: 12, color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Draws a line scaled to the min/max of the values.
class SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-9) {
      hi = lo + 1; // flat line in the middle
      lo = lo - 1;
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = 2 + (size.height - 4) * (1 - (values[i] - lo) / (hi - lo));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant SparklinePainter old) => old.values != values || old.color != color;
}

/// The four headline cards (error rate, p95 latency, CPU, memory) for one service.
class ServiceMetricsGrid extends StatelessWidget {
  final ServiceMetrics metrics;
  final VoidCallback? onTap;
  final double chartHeight;

  const ServiceMetricsGrid({super.key, required this.metrics, this.onTap, this.chartHeight = 36});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = metrics;
    final err = m.errorRate.current;
    final lat = m.latencyP95Seconds.current;
    final errColor = err != null && err >= m.errorRateThreshold ? colors.critical : colors.success;
    final latColor = lat != null && lat >= m.latencyThresholdSeconds ? colors.critical : colors.success;
    Widget row(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)],
        );
    return Column(
      children: [
        row(
          MetricCard(
            title: 'Error rate',
            value: MetricFormat.percent(err),
            sub: 'Alert above ${MetricFormat.percent(m.errorRateThreshold)}',
            values: m.errorRate.values,
            color: errColor,
            onTap: onTap,
            chartHeight: chartHeight,
          ),
          MetricCard(
            title: 'P95 latency',
            value: MetricFormat.seconds(lat),
            sub: 'Alert above ${MetricFormat.seconds(m.latencyThresholdSeconds)}',
            values: m.latencyP95Seconds.values,
            color: latColor,
            onTap: onTap,
            chartHeight: chartHeight,
          ),
        ),
        const SizedBox(height: 8),
        row(
          MetricCard(
            title: 'CPU',
            value: MetricFormat.cpu(m.cpuPercent.current),
            sub: '% of one core',
            values: m.cpuPercent.values,
            color: colors.warning,
            onTap: onTap,
            chartHeight: chartHeight,
          ),
          MetricCard(
            title: 'Memory',
            value: MetricFormat.bytes(m.memoryBytes.current),
            sub: 'Resident memory',
            values: m.memoryBytes.values,
            color: colors.info,
            onTap: onTap,
            chartHeight: chartHeight,
          ),
        ),
      ],
    );
  }
}

/// Coloured bar + counts for a list of services.
class ServiceHealthBar extends StatelessWidget {
  final List<ServiceHealth> services;

  const ServiceHealthBar({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final healthy = services.where((s) => s.status == 'healthy').length;
    final warning = services.where((s) => s.status == 'warning').length;
    final down = services.where((s) => s.status == 'down').length;
    Widget seg(int n, Color c) => n == 0 ? const SizedBox.shrink() : Expanded(flex: n, child: Container(color: c));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: services.isEmpty
                ? Container(color: colors.border)
                : Row(children: [seg(healthy, colors.ok), seg(warning, colors.warning), seg(down, colors.critical)]),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          services.isEmpty ? 'No services reported by Prometheus' : '$healthy healthy  $warning warning  $down down',
          style: TextStyle(fontSize: 13, color: colors.muted),
        ),
      ],
    );
  }
}
