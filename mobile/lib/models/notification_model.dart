/// In-App & Push Notification Data Models
/// Based on Vinuka's (M5) Backend Notification API Specification (Nov 2026)
/// Used by S25 (Notifications), S27 (Preferences), and deep-linking services
library;

import 'package:flutter/material.dart';

/// Notification delivery channels supported by backend
enum NotificationChannel {
  inApp,
  push,
  email,
  slack,
  discord;

  String get slug {
    switch (this) {
      case NotificationChannel.inApp:
        return 'in_app';
      case NotificationChannel.push:
        return 'push';
      case NotificationChannel.email:
        return 'email';
      case NotificationChannel.slack:
        return 'slack';
      case NotificationChannel.discord:
        return 'discord';
    }
  }

  String get displayName {
    switch (this) {
      case NotificationChannel.inApp:
        return 'In-App Feed';
      case NotificationChannel.push:
        return 'Push Notification';
      case NotificationChannel.email:
        return 'Email Alert';
      case NotificationChannel.slack:
        return 'Slack Channel';
      case NotificationChannel.discord:
        return 'Discord Bot';
    }
  }

  static NotificationChannel fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'in_app':
      case 'inapp':
        return NotificationChannel.inApp;
      case 'push':
      case 'fcm':
        return NotificationChannel.push;
      case 'email':
        return NotificationChannel.email;
      case 'slack':
        return NotificationChannel.slack;
      case 'discord':
        return NotificationChannel.discord;
      default:
        return NotificationChannel.inApp;
    }
  }
}

/// Category derived from title, message, or payload for UI styling & deep linking
enum NotificationCategory {
  incidentAlert,
  approvalRequest,
  remediationResult,
  recoveryResolution,
  systemNotice;

  String get displayName {
    switch (this) {
      case NotificationCategory.incidentAlert:
        return 'Incident Alert';
      case NotificationCategory.approvalRequest:
        return 'Approval Required';
      case NotificationCategory.remediationResult:
        return 'Remediation';
      case NotificationCategory.recoveryResolution:
        return 'Resolution';
      case NotificationCategory.systemNotice:
        return 'System Alert';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationCategory.incidentAlert:
        return Icons.warning_amber_rounded;
      case NotificationCategory.approvalRequest:
        return Icons.lock_clock_rounded;
      case NotificationCategory.remediationResult:
        return Icons.play_circle_outline_rounded;
      case NotificationCategory.recoveryResolution:
        return Icons.check_circle_outline_rounded;
      case NotificationCategory.systemNotice:
        return Icons.notifications_none_rounded;
    }
  }

  String get targetRoute {
    switch (this) {
      case NotificationCategory.incidentAlert:
        return '/incident-details';
      case NotificationCategory.approvalRequest:
        return '/approve-action';
      case NotificationCategory.remediationResult:
        return '/execution-progress';
      case NotificationCategory.recoveryResolution:
        return '/recovery-verification';
      case NotificationCategory.systemNotice:
        return '/dashboard';
    }
  }
}

/// Notification Record Model (Matches Vinuka's GET /api/notifications response)
class NotificationModel {
  final String id;
  final String? userId;
  final String? incidentId;
  final String title;
  final String message;
  final NotificationChannel channel;
  final String status;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? readAt;
  final Map<String, dynamic>? extraData;

  NotificationModel({
    required this.id,
    this.userId,
    this.incidentId,
    required this.title,
    required this.message,
    required this.channel,
    this.status = 'sent',
    required this.createdAt,
    this.sentAt,
    this.readAt,
    this.extraData,
  });

  /// Derived property specified by Vinuka: isRead = read_at != null
  bool get isRead => readAt != null;

  /// Derived category for visual badge, icon, and deep-link routing
  NotificationCategory get category {
    final t = title.toLowerCase();
    final m = message.toLowerCase();

    if (t.contains('approval') || m.contains('approval') || t.contains('confirm') || m.contains('confirm')) {
      return NotificationCategory.approvalRequest;
    }
    if (t.contains('resolved') || m.contains('resolved') || t.contains('recovered') || m.contains('recovered')) {
      return NotificationCategory.recoveryResolution;
    }
    if (t.contains('remediation') || m.contains('execution') || t.contains('rollback') || t.contains('restart')) {
      return NotificationCategory.remediationResult;
    }
    if (t.contains('critical') || t.contains('incident') || m.contains('incident') || t.contains('failure')) {
      return NotificationCategory.incidentAlert;
    }
    return NotificationCategory.systemNotice;
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? 'notif-${DateTime.now().millisecondsSinceEpoch}',
      userId: json['user_id'] as String?,
      incidentId: json['incident_id'] as String?,
      title: json['title'] as String? ?? 'Notification Alert',
      message: json['message'] as String? ?? '',
      channel: NotificationChannel.fromString(json['channel'] as String?),
      status: json['status'] as String? ?? 'sent',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sentAt: json['sent_at'] != null ? DateTime.tryParse(json['sent_at'].toString()) : null,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      extraData: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'incident_id': incidentId,
        'title': title,
        'message': message,
        'channel': channel.slug,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'sent_at': sentAt?.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
      };

  NotificationModel copyWith({
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id,
      userId: userId,
      incidentId: incidentId,
      title: title,
      message: message,
      channel: channel,
      status: status,
      createdAt: createdAt,
      sentAt: sentAt,
      readAt: readAt ?? this.readAt,
      extraData: extraData,
    );
  }
}
