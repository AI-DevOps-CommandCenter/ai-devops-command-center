/// System Health & Performance Metrics Model
class MetricModel {
  final double cpuUsage;
  final double memoryUsage;
  final double errorRate;
  final int latencyMs;
  final DateTime timestamp;

  MetricModel({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.errorRate,
    required this.latencyMs,
    required this.timestamp,
  });

  factory MetricModel.fromJson(Map<String, dynamic> json) {
    return MetricModel(
      cpuUsage: (json['cpu_usage'] as num?)?.toDouble() ?? 0.0,
      memoryUsage: (json['memory_usage'] as num?)?.toDouble() ?? 0.0,
      errorRate: (json['error_rate'] as num?)?.toDouble() ?? 0.0,
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'error_rate': errorRate,
      'latency_ms': latencyMs,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
