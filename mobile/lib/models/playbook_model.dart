/// Remediation Playbook & Approval Models
/// Based on Vinuka's (M5) Backend API Specification (Nov 2026)
/// Used by S18 (Approve Action), S19 (Execution Progress), S20 (Recovery Verification)
library;

import 'package:flutter/material.dart';

/// Supported playbook remediation action types in the backend
enum PlaybookActionType {
  restart,
  rollback,
  scale,
  circuitBreaker;

  String get slug {
    switch (this) {
      case PlaybookActionType.restart:
        return 'restart';
      case PlaybookActionType.rollback:
        return 'rollback';
      case PlaybookActionType.scale:
        return 'scale';
      case PlaybookActionType.circuitBreaker:
        return 'circuit_breaker';
    }
  }

  String get displayName {
    switch (this) {
      case PlaybookActionType.restart:
        return 'Restart Service';
      case PlaybookActionType.rollback:
        return 'Roll Back Deployment';
      case PlaybookActionType.scale:
        return 'Scale Replicas';
      case PlaybookActionType.circuitBreaker:
        return 'Apply Circuit Breaker';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaybookActionType.restart:
        return Icons.restart_alt_rounded;
      case PlaybookActionType.rollback:
        return Icons.history_rounded;
      case PlaybookActionType.scale:
        return Icons.speed_rounded;
      case PlaybookActionType.circuitBreaker:
        return Icons.shield_outlined;
    }
  }

  static PlaybookActionType fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'restart':
        return PlaybookActionType.restart;
      case 'rollback':
      case 'roll_back':
        return PlaybookActionType.rollback;
      case 'scale':
        return PlaybookActionType.scale;
      case 'circuit_breaker':
      case 'circuitbreaker':
        return PlaybookActionType.circuitBreaker;
      default:
        return PlaybookActionType.rollback;
    }
  }
}

/// Lifecycle statuses for playbook runs reported by backend and n8n engine
enum PlaybookRunStatus {
  pendingApproval,
  approved,
  running,
  success,
  failed,
  rejected,
  cancelled;

  String get slug {
    switch (this) {
      case PlaybookRunStatus.pendingApproval:
        return 'pending_approval';
      case PlaybookRunStatus.approved:
        return 'approved';
      case PlaybookRunStatus.running:
        return 'running';
      case PlaybookRunStatus.success:
        return 'success';
      case PlaybookRunStatus.failed:
        return 'failed';
      case PlaybookRunStatus.rejected:
        return 'rejected';
      case PlaybookRunStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case PlaybookRunStatus.pendingApproval:
        return 'Pending Approval';
      case PlaybookRunStatus.approved:
        return 'Approved';
      case PlaybookRunStatus.running:
        return 'Running';
      case PlaybookRunStatus.success:
        return 'Success';
      case PlaybookRunStatus.failed:
        return 'Failed';
      case PlaybookRunStatus.rejected:
        return 'Rejected';
      case PlaybookRunStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isPending => this == PlaybookRunStatus.pendingApproval;
  bool get isApproved => this == PlaybookRunStatus.approved;
  bool get isRunning => this == PlaybookRunStatus.running;
  bool get isSuccess => this == PlaybookRunStatus.success;
  bool get isFailed => this == PlaybookRunStatus.failed;
  bool get isRejected => this == PlaybookRunStatus.rejected;
  bool get isCancelled => this == PlaybookRunStatus.cancelled;

  static PlaybookRunStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'pending_approval':
      case 'pending':
        return PlaybookRunStatus.pendingApproval;
      case 'approved':
        return PlaybookRunStatus.approved;
      case 'running':
      case 'in_progress':
        return PlaybookRunStatus.running;
      case 'success':
      case 'completed':
        return PlaybookRunStatus.success;
      case 'failed':
      case 'failure':
        return PlaybookRunStatus.failed;
      case 'rejected':
        return PlaybookRunStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return PlaybookRunStatus.cancelled;
      default:
        return PlaybookRunStatus.pendingApproval;
    }
  }
}

/// Administrator-managed Playbook definition
class PlaybookModel {
  final String id;
  final String name;
  final PlaybookActionType actionType;
  final String description;
  final String impactDescription;
  final Map<String, dynamic> defaultPayload;

  PlaybookModel({
    required this.id,
    required this.name,
    required this.actionType,
    required this.description,
    required this.impactDescription,
    this.defaultPayload = const {},
  });

  factory PlaybookModel.fromJson(Map<String, dynamic> json) {
    return PlaybookModel(
      id: json['id'] as String? ?? json['playbook_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Playbook Action',
      actionType: PlaybookActionType.fromString(json['action_type'] as String?),
      description: json['description'] as String? ?? '',
      impactDescription: json['impact_description'] as String? ??
          'Impact: brief request failures during switchover (about 30 s).',
      defaultPayload: json['default_payload'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// An execution step within a Playbook Run (used in S19 timeline)
class PlaybookExecutionStep {
  final String time;
  final String title;
  final String detail;
  final String status; // 'completed', 'running', 'pending', 'failed'

  const PlaybookExecutionStep({
    required this.time,
    required this.title,
    required this.detail,
    required this.status,
  });

  factory PlaybookExecutionStep.fromJson(Map<String, dynamic> json) {
    return PlaybookExecutionStep(
      time: json['time'] as String? ?? '--:--',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'title': title,
        'detail': detail,
        'status': status,
      };
}

/// Playbook Run execution record (POST /api/playbook-runs, GET /api/playbook-runs/:id)
class PlaybookRunModel {
  final String id;
  final String incidentId;
  final String playbookId;
  final String? approvalId;
  final PlaybookActionType actionType;
  final PlaybookRunStatus status;
  final Map<String, dynamic> requestPayload;
  final String serviceName;
  final String environment;
  final String fromVersion;
  final String toVersion;
  final String requestedBy;
  final String? decidedBy;
  final String? comments;
  final String? cancellationReason;
  final String? idempotencyKey;
  final String? n8nExecutionId;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? resultMessage;
  final List<PlaybookExecutionStep> steps;

  PlaybookRunModel({
    required this.id,
    required this.incidentId,
    required this.playbookId,
    this.approvalId,
    required this.actionType,
    required this.status,
    this.requestPayload = const {},
    this.serviceName = 'payments-api',
    this.environment = 'Production',
    this.fromVersion = 'v2.8.1',
    this.toVersion = 'v2.8.0',
    this.requestedBy = 'Alex Morgan',
    this.decidedBy,
    this.comments,
    this.cancellationReason,
    this.idempotencyKey,
    this.n8nExecutionId,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.resultMessage,
    this.steps = const [],
  });

  factory PlaybookRunModel.fromJson(Map<String, dynamic> json) {
    final payload = json['request_payload'] as Map<String, dynamic>? ?? {};
    final stepsJson = json['steps'] as List<dynamic>?;

    return PlaybookRunModel(
      id: json['id'] as String? ?? json['playbook_run_id'] as String? ?? '',
      incidentId: json['incident_id'] as String? ?? 'INC-1042',
      playbookId: json['playbook_id'] as String? ?? '',
      approvalId: json['approval_id'] as String?,
      actionType: PlaybookActionType.fromString(
        json['action_type'] as String? ?? payload['action'] as String?,
      ),
      status: PlaybookRunStatus.fromString(json['status'] as String?),
      requestPayload: payload,
      serviceName: payload['service'] as String? ?? json['service_name'] as String? ?? 'payments-api',
      environment: payload['environment'] as String? ?? json['environment'] as String? ?? 'Production',
      fromVersion: payload['from_version'] as String? ?? 'v2.8.1',
      toVersion: payload['to_version'] as String? ?? 'v2.8.0',
      requestedBy: json['requested_by'] as String? ?? 'Alex Morgan',
      decidedBy: json['decided_by'] as String?,
      comments: json['comments'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
      n8nExecutionId: json['n8n_execution_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      resultMessage: json['result'] is Map ? (json['result']['message'] as String?) : json['result_message'] as String?,
      steps: stepsJson != null
          ? stepsJson.map((e) => PlaybookExecutionStep.fromJson(e as Map<String, dynamic>)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'incident_id': incidentId,
        'playbook_id': playbookId,
        'approval_id': approvalId,
        'action_type': actionType.slug,
        'status': status.slug,
        'request_payload': requestPayload,
        'service_name': serviceName,
        'environment': environment,
        'requested_by': requestedBy,
        'decided_by': decidedBy,
        'comments': comments,
        'cancellation_reason': cancellationReason,
        'idempotency_key': idempotencyKey,
        'n8n_execution_id': n8nExecutionId,
        'created_at': createdAt?.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'result_message': resultMessage,
        'steps': steps.map((e) => e.toJson()).toList(),
      };
}

/// Approval item model (GET /api/approvals?status=pending)
class ApprovalModel {
  final String id;
  final String playbookRunId;
  final String incidentId;
  final String playbookId;
  final PlaybookActionType actionType;
  final String status;
  final String requestedBy;
  final String serviceName;
  final String environment;
  final String fromVersion;
  final String toVersion;
  final String impactDescription;
  final Map<String, dynamic> requestPayload;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? comments;

  ApprovalModel({
    required this.id,
    required this.playbookRunId,
    required this.incidentId,
    required this.playbookId,
    required this.actionType,
    required this.status,
    required this.requestedBy,
    this.serviceName = 'payments-api',
    this.environment = 'Production',
    this.fromVersion = 'v2.8.1',
    this.toVersion = 'v2.8.0',
    this.impactDescription = 'Impact: brief request failures during switchover (about 30 s). Nothing runs until you confirm.',
    this.requestPayload = const {},
    this.createdAt,
    this.decidedAt,
    this.decidedBy,
    this.comments,
  });

  factory ApprovalModel.fromJson(Map<String, dynamic> json) {
    final payload = json['request_payload'] as Map<String, dynamic>? ?? {};

    return ApprovalModel(
      id: json['id'] as String? ?? json['approval_id'] as String? ?? '',
      playbookRunId: json['playbook_run_id'] as String? ?? json['run_id'] as String? ?? '',
      incidentId: json['incident_id'] as String? ?? 'INC-1042',
      playbookId: json['playbook_id'] as String? ?? '',
      actionType: PlaybookActionType.fromString(
        json['action_type'] as String? ?? payload['action'] as String?,
      ),
      status: json['status'] as String? ?? 'pending',
      requestedBy: json['requested_by'] as String? ?? 'Alex Morgan',
      serviceName: payload['service'] as String? ?? json['service_name'] as String? ?? 'payments-api',
      environment: payload['environment'] as String? ?? json['environment'] as String? ?? 'Production',
      fromVersion: payload['from_version'] as String? ?? 'v2.8.1',
      toVersion: payload['to_version'] as String? ?? 'v2.8.0',
      impactDescription: json['impact_description'] as String? ??
          'Impact: brief request failures during switchover (about 30 s). Nothing runs until you confirm.',
      requestPayload: payload,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      decidedAt: json['decided_at'] != null ? DateTime.tryParse(json['decided_at'].toString()) : null,
      decidedBy: json['decided_by'] as String?,
      comments: json['comments'] as String?,
    );
  }
}
