import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/notification_model.dart';
import 'package:mobile/services/foreground_push_banner.dart';

NotificationModel _push(String title, String message, {String? incidentId}) => NotificationModel(
      id: 'fcm-1',
      incidentId: incidentId,
      title: title,
      message: message,
      channel: NotificationChannel.push,
      createdAt: DateTime(2026, 11, 21, 15, 58),
    );

Widget _app() => MaterialApp(
      navigatorKey: ForegroundPushBanner.navigatorKey,
      scaffoldMessengerKey: ForegroundPushBanner.messengerKey,
      home: const Scaffold(body: Text('home')),
      routes: {
        '/incident-details': (context) =>
            Scaffold(body: Text('incident ${ModalRoute.of(context)!.settings.arguments}')),
      },
    );

void main() {
  late StreamController<NotificationModel> pushes;

  setUp(() {
    pushes = StreamController<NotificationModel>.broadcast();
    ForegroundPushBanner.start(pushes.stream);
  });

  tearDown(() async {
    await ForegroundPushBanner.stop();
    await pushes.close();
  });

  testWidgets('a foreground push shows a banner with title and message', (tester) async {
    await tester.pumpWidget(_app());
    pushes.add(_push('New incident: HighErrorRate on sample-app', 'Error rate above 5% on sample-app'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('New incident: HighErrorRate on sample-app'), findsOneWidget);
    expect(find.text('Error rate above 5% on sample-app'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('"Open" follows the deep link to the incident', (tester) async {
    await tester.pumpWidget(_app());
    pushes.add(_push('New incident: HighErrorRate', 'sample-app', incidentId: 'inc-42'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('incident inc-42'), findsOneWidget);
  });

  testWidgets('start() twice does not show the banner twice', (tester) async {
    ForegroundPushBanner.start(pushes.stream);
    await tester.pumpWidget(_app());
    pushes.add(_push('Run finished', 'restart succeeded'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Run finished'), findsOneWidget);
  });
}
