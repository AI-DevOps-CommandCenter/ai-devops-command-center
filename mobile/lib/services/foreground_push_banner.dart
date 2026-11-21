import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import 'notification_service.dart';

/// Shows a push that arrives while the app is open (foreground).
///
/// Android and the browser only show FCM notifications themselves when the app
/// is in the background. In the foreground, NotificationService passes the
/// message to [NotificationService.onNotificationReceived]; this shows it as a
/// floating banner with an "Open" button that uses the same deep links as the
/// notifications screen.
class ForegroundPushBanner {
  ForegroundPushBanner._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static StreamSubscription<NotificationModel>? _subscription;

  /// Starts listening once; later calls do nothing.
  static void start([Stream<NotificationModel>? stream]) {
    _subscription ??= (stream ?? NotificationService().onNotificationReceived).listen(show);
  }

  static void show(NotificationModel notification) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (notification.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(notification.message, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            final context = navigatorKey.currentContext;
            if (context != null) NotificationService().handleDeepLink(context, notification);
          },
        ),
      ));
  }

  /// For tests.
  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
