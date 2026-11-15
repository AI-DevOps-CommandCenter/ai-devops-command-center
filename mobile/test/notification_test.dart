import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/notification_model.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  group('Notification & FCM Models Tests (Vinuka M5 Spec)', () {
    test('NotificationModel correctly derives isRead from read_at', () {
      final unreadJson = {
        'id': 'notif-101',
        'user_id': 'user-1',
        'incident_id': 'INC-1042',
        'title': 'Critical Incident Detected',
        'message': 'HTTP 500 error spike detected on payments-api',
        'channel': 'push',
        'status': 'sent',
        'created_at': '2026-11-12T03:00:00Z',
        'sent_at': '2026-11-12T03:00:02Z',
        'read_at': null,
      };

      final unreadModel = NotificationModel.fromJson(unreadJson);
      expect(unreadModel.id, 'notif-101');
      expect(unreadModel.isRead, false);
      expect(unreadModel.channel, NotificationChannel.push);
      expect(unreadModel.category, NotificationCategory.incidentAlert);
      expect(unreadModel.category.targetRoute, '/incident-details');

      final readJson = Map<String, dynamic>.from(unreadJson);
      readJson['read_at'] = '2026-11-12T03:05:00Z';
      final readModel = NotificationModel.fromJson(readJson);
      expect(readModel.isRead, true);
    });

    test('NotificationChannel handles all 5 supported backend channels', () {
      expect(NotificationChannel.fromString('in_app'), NotificationChannel.inApp);
      expect(NotificationChannel.fromString('push'), NotificationChannel.push);
      expect(NotificationChannel.fromString('email'), NotificationChannel.email);
      expect(NotificationChannel.fromString('slack'), NotificationChannel.slack);
      expect(NotificationChannel.fromString('discord'), NotificationChannel.discord);

      expect(NotificationChannel.push.slug, 'push');
      expect(NotificationChannel.inApp.slug, 'in_app');
      expect(NotificationChannel.slack.slug, 'slack');
    });

    test('NotificationCategory correctly maps to deep linking routes', () {
      expect(NotificationCategory.incidentAlert.targetRoute, '/incident-details');
      expect(NotificationCategory.approvalRequest.targetRoute, '/approve-action');
      expect(NotificationCategory.remediationResult.targetRoute, '/execution-progress');
      expect(NotificationCategory.recoveryResolution.targetRoute, '/recovery-verification');
    });

    test('ApiService fetches notifications and updates read status', () async {
      final api = ApiService();
      final list = await api.fetchNotifications();
      expect(list.isNotEmpty, true);
      expect(list.first.incidentId, 'INC-1042');

      final success = await api.markNotificationAsRead('notif-101');
      expect(success, true);
    });

    test('ApiService registers and unregisters FCM device tokens', () async {
      final api = ApiService();
      final regSuccess = await api.registerDeviceToken('test-fcm-token-123', platform: 'android');
      expect(regSuccess, true);

      final unregSuccess = await api.unregisterDeviceToken('test-fcm-token-123');
      expect(unregSuccess, true);
    });

    test('ApiService loads and saves notification preferences', () async {
      final api = ApiService();
      final prefs = await api.fetchNotificationPreferences();
      expect(prefs.containsKey('Push-Detection'), true);
      expect(prefs['Push-Detection'], true);

      final saved = await api.saveNotificationPreferences(prefs);
      expect(saved, true);
    });
  });
}
