/// Incident Model representing production incidents, root cause, and evidence
enum IncidentSeverity { critical, high, medium, low }
enum IncidentStatus { open, investigating, remediating, resolved }

class IncidentEvidence {
  final List<String> logSnippets;
  final String metricAnomaly;
  final String? relatedCommitSha;
  final String? relatedDeploymentId;

  IncidentEvidence({
    required this.logSnippets,
    required this.metricAnomaly,
    this.relatedCommitSha,
    this.relatedDeploymentId,
  });

  factory IncidentEvidence.fromJson(Map<String, dynamic> json) {
    return IncidentEvidence(
      logSnippets: List<String>.from(json['log_snippets'] ?? []),
      metricAnomaly: json['metric_anomaly']?.toString() ?? 'Anomaly detected',
      relatedCommitSha: json['related_commit_sha']?.toString(),
      relatedDeploymentId: json['related_deployment_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_snippets': logSnippets,
      'metric_anomaly': metricAnomaly,
      'related_commit_sha': relatedCommitSha,
      'related_deployment_id': relatedDeploymentId,
    };
  }
}

class IncidentModel {
  final String id;
  final String title;
  final String serviceName;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final DateTime detectedAt;
  final String summary;
  final String? rootCause;
  final IncidentEvidence? evidence;
  final String? recommendedPlaybookId;
  final double? cpuUsage;
  final double? memoryUsage;
  final double? errorRate;

  IncidentModel({
    required this.id,
    required this.title,
    required this.serviceName,
    required this.severity,
    required this.status,
    required this.detectedAt,
    required this.summary,
    this.rootCause,
    this.evidence,
    this.recommendedPlaybookId,
    this.cpuUsage,
    this.memoryUsage,
    this.errorRate,
  });

  bool get isResolved => status == IncidentStatus.resolved;

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Incident',
      serviceName: json['service_name']?.toString() ?? 'System',
      severity: _parseSeverity(json['severity']),
      status: _parseStatus(json['status']),
      detectedAt: DateTime.tryParse(json['detected_at']?.toString() ?? '') ?? DateTime.now(),
      summary: json['summary']?.toString() ?? '',
      rootCause: json['root_cause']?.toString(),
      evidence: json['evidence'] != null ? IncidentEvidence.fromJson(json['evidence']) : null,
      recommendedPlaybookId: json['recommended_playbook_id']?.toString(),
      cpuUsage: (json['cpu_usage'] as num?)?.toDouble(),
      memoryUsage: (json['memory_usage'] as num?)?.toDouble(),
      errorRate: (json['error_rate'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'service_name': serviceName,
      'severity': severity.name,
      'status': status.name,
      'detected_at': detectedAt.toIso8601String(),
      'summary': summary,
      'root_cause': rootCause,
      'evidence': evidence?.toJson(),
      'recommended_playbook_id': recommendedPlaybookId,
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'error_rate': errorRate,
    };
  }

  static IncidentSeverity _parseSeverity(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'critical': return IncidentSeverity.critical;
      case 'high': return IncidentSeverity.high;
      case 'medium': return IncidentSeverity.medium;
      default: return IncidentSeverity.low;
    }
  }

  static IncidentStatus _parseStatus(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'investigating': return IncidentStatus.investigating;
      case 'remediating': return IncidentStatus.remediating;
      case 'resolved': return IncidentStatus.resolved;
      default: return IncidentStatus.open;
    }
  }
}
