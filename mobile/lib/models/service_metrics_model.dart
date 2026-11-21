/// Models for GET /api/metrics/services and /api/metrics/services/:service
/// (backend reads them from Prometheus).
library;

class ServiceHealth {
  final String service;
  final bool up;
  final double? errorRate;
  final String status; // healthy | warning | down

  ServiceHealth({required this.service, required this.up, this.errorRate, required this.status});

  factory ServiceHealth.fromJson(Map<String, dynamic> json) => ServiceHealth(
        service: json['service']?.toString() ?? '',
        up: json['up'] == true,
        errorRate: (json['error_rate'] as num?)?.toDouble(),
        status: json['status']?.toString() ?? 'down',
      );
}

class MetricPoint {
  final DateTime time;
  final double? value;
  MetricPoint(this.time, this.value);
}

class MetricSeries {
  final double? current;
  final List<MetricPoint> points;

  MetricSeries({this.current, this.points = const []});

  factory MetricSeries.fromJson(dynamic json) {
    if (json is! Map) return MetricSeries();
    final pts = json['points'] is List ? json['points'] as List : const [];
    return MetricSeries(
      current: (json['current'] as num?)?.toDouble(),
      points: pts
          .whereType<Map>()
          .map((p) => MetricPoint(
                DateTime.fromMillisecondsSinceEpoch(((p['t'] as num?) ?? 0).toInt() * 1000),
                (p['v'] as num?)?.toDouble(),
              ))
          .toList(),
    );
  }

  List<double> get values => points.map((p) => p.value).whereType<double>().toList();
}

class ServiceMetrics {
  final String service;
  final int windowMinutes;
  final double errorRateThreshold;
  final double latencyThresholdSeconds;
  final MetricSeries errorRate;
  final MetricSeries latencyP95Seconds;
  final MetricSeries requestRate;
  final MetricSeries cpuPercent;
  final MetricSeries memoryBytes;

  ServiceMetrics({
    required this.service,
    required this.windowMinutes,
    required this.errorRateThreshold,
    required this.latencyThresholdSeconds,
    required this.errorRate,
    required this.latencyP95Seconds,
    required this.requestRate,
    required this.cpuPercent,
    required this.memoryBytes,
  });

  factory ServiceMetrics.fromJson(Map<String, dynamic> json) {
    final t = json['thresholds'] is Map ? json['thresholds'] as Map : const {};
    return ServiceMetrics(
      service: json['service']?.toString() ?? '',
      windowMinutes: (json['window_minutes'] as num?)?.toInt() ?? 60,
      errorRateThreshold: (t['errorRate'] as num?)?.toDouble() ?? 0.05,
      latencyThresholdSeconds: (t['latencyP95Seconds'] as num?)?.toDouble() ?? 0.5,
      errorRate: MetricSeries.fromJson(json['error_rate']),
      latencyP95Seconds: MetricSeries.fromJson(json['latency_p95_seconds']),
      requestRate: MetricSeries.fromJson(json['request_rate']),
      cpuPercent: MetricSeries.fromJson(json['cpu_percent']),
      memoryBytes: MetricSeries.fromJson(json['memory_bytes']),
    );
  }
}

/// One log line from GET /api/logs/services/:service (Loki).
class LogLineModel {
  final DateTime time;
  final String? level;
  final String message;
  final String? logger;
  final String raw;

  LogLineModel({required this.time, this.level, required this.message, this.logger, required this.raw});

  factory LogLineModel.fromJson(Map<String, dynamic> json) => LogLineModel(
        time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        level: json['level']?.toString(),
        message: json['message']?.toString() ?? '',
        logger: json['logger']?.toString(),
        raw: json['raw']?.toString() ?? '',
      );
}

/// Display helpers shared by the metric screens.
class MetricFormat {
  static String percent(double? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(v < 0.1 ? 2 : 1)}%';
  static String seconds(double? v) =>
      v == null ? '—' : v < 1 ? '${(v * 1000).round()} ms' : '${v.toStringAsFixed(2)} s';
  static String perSecond(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} req/s';
  static String cpu(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';
  static String bytes(double? v) {
    if (v == null) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var x = v;
    var i = 0;
    while (x >= 1024 && i < units.length - 1) {
      x /= 1024;
      i++;
    }
    return '${x.toStringAsFixed(x < 10 ? 1 : 0)} ${units[i]}';
  }
}
