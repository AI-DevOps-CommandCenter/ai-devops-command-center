/// Service Health Model matching Vinuka's GET /api/services endpoint
enum ServiceStatus { healthy, degraded, down, unknown }
enum ServiceEnvironment { production, staging, testing, development }

class ServiceModel {
  final String id;
  final String name;
  final String? description;
  final ServiceEnvironment environment;
  final String? endpoint;
  final ServiceStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ServiceModel({
    required this.id,
    required this.name,
    this.description,
    this.environment = ServiceEnvironment.production,
    this.endpoint,
    this.status = ServiceStatus.healthy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isHealthy => status == ServiceStatus.healthy;

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Service',
      description: json['description']?.toString(),
      environment: _parseEnvironment(json['environment']),
      endpoint: json['endpoint']?.toString(),
      status: _parseStatus(json['status']),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'environment': environment.name,
      'endpoint': endpoint,
      'status': status.name,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static ServiceStatus _parseStatus(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'healthy': return ServiceStatus.healthy;
      case 'degraded': return ServiceStatus.degraded;
      case 'down': return ServiceStatus.down;
      default: return ServiceStatus.unknown;
    }
  }

  static ServiceEnvironment _parseEnvironment(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'staging': return ServiceEnvironment.staging;
      case 'testing': return ServiceEnvironment.testing;
      case 'development': return ServiceEnvironment.development;
      default: return ServiceEnvironment.production;
    }
  }
}
