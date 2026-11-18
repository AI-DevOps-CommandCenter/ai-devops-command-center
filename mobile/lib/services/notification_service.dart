import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

/// Central Notification Service managing Firebase Messaging (FCM) & In-App Alerts
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ApiService _apiService = ApiService();

  /// Web push needs the Firebase web VAPID public key. It is passed at build
  /// time and is not stored in git:
  ///   flutter run -d chrome --dart-define=FCM_WEB_VAPID_KEY=YOUR_KEY
  /// Without it, web gets no push token (in-app notifications still work).
  static const String _webVapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');

  bool _isInitialized = false;
  bool _signedIn = false;
  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  final StreamController<NotificationModel> _notificationStreamController =
      StreamController<NotificationModel>.broadcast();

  Stream<NotificationModel> get onNotificationReceived =>
      _notificationStreamController.stream;
  String? get fcmToken => _fcmToken;

  /// Initializes Firebase and requests Push Notification permissions
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase with Vishwa's google-services.json options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Request push notification permission
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 3. Retrieve the real FCM device token. It is registered with the
        //    backend (POST /api/device-tokens) only after sign-in, because the
        //    route needs the user's session (see registerTokenOnLogin).
        if (!kIsWeb) {
          _fcmToken = await messaging.getToken();
        } else if (_webVapidKey.isNotEmpty) {
          _fcmToken = await messaging.getToken(vapidKey: _webVapidKey);
        } else {
          debugPrint('[push] FCM_WEB_VAPID_KEY not set: web push is off.');
        }

        // 4. FCM can replace the token; register the new one while signed in.
        _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) async {
          final old = _fcmToken;
          _fcmToken = token;
          if (_signedIn) {
            if (old != null && old != token) await _apiService.unregisterDeviceToken(old);
            await _apiService.registerDeviceToken(token, platform: _platform);
          }
        });

        // 5. Listen to foreground FCM messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _handleIncomingRemoteMessage(message);
        });

        // 6. Handle notification click when app opened from background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationClick(message);
        });
      }
    } catch (e) {
      // No push on this device (Firebase unavailable, permission error...).
      // No token is invented: the app keeps working with in-app notifications.
      _fcmToken = null;
      debugPrint('[push] push notifications unavailable: $e');
    }

    _isInitialized = true;
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  /// Register the FCM token after the user signs in. Does nothing when this
  /// device has no push token.
  Future<void> registerTokenOnLogin() async {
    _signedIn = true;
    final token = _fcmToken;
    if (token == null) return;
    await _apiService.registerDeviceToken(token, platform: _platform);
  }

  /// Unregister the FCM token on sign-out, so this device gets no more pushes
  /// for that user.
  Future<void> unregisterTokenOnLogout() async {
    _signedIn = false;
    if (_fcmToken != null) {
      await _apiService.unregisterDeviceToken(_fcmToken!);
    }
  }

  void _handleIncomingRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notification = NotificationModel(
      id: message.messageId ?? 'fcm-${DateTime.now().millisecondsSinceEpoch}',
      incidentId: data['incident_id'] as String?,
      title: message.notification?.title ?? data['title'] as String? ?? 'New DevOps Alert',
      message: message.notification?.body ?? data['message'] as String? ?? '',
      channel: NotificationChannel.push,
      status: 'sent',
      createdAt: DateTime.now(),
      sentAt: DateTime.now(),
      extraData: data,
    );

    _notificationStreamController.add(notification);
  }

  void _handleNotificationClick(RemoteMessage message) {
    // Process deep linking payload
  }

  /// Deep Link Navigator: Navigates to target screen based on Notification category
  void handleDeepLink(BuildContext context, NotificationModel notification) {
    final category = notification.category;
    final incidentId = notification.incidentId;
    if (incidentId == null || incidentId.isEmpty) {
      Navigator.pushNamed(context, '/notifications');
      return;
    }

    switch (category) {
      case NotificationCategory.incidentAlert:
        Navigator.pushNamed(context, '/incident-details', arguments: incidentId);
        break;
      case NotificationCategory.approvalRequest:
        Navigator.pushNamed(context, '/approve-action', arguments: incidentId);
        break;
      case NotificationCategory.remediationResult:
        Navigator.pushNamed(context, '/execution-progress', arguments: incidentId);
        break;
      case NotificationCategory.recoveryResolution:
        Navigator.pushNamed(context, '/recovery-verification', arguments: incidentId);
        break;
      case NotificationCategory.systemNotice:
        Navigator.pushNamed(context, '/dashboard');
        break;
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _notificationStreamController.close();
  }
}
