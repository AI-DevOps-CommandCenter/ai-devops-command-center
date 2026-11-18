import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/screens/s27_notification_preferences_screen.dart';
import 'package:mobile/services/notification_preferences_service.dart';

Map<String, dynamic> prefsJson({bool push = true, bool email = false, String? updatedAt, bool slack = false}) => {
      'success': true,
      'data': {
        'push_enabled': push,
        'email_enabled': email,
        'updated_at': updatedAt,
        'in_app_enabled': true,
        'server_channels': {'push': false, 'email': false, 'slack': slack, 'discord': false},
      },
    };

NotificationPreferencesService serviceWith(Future<http.Response> Function(http.Request) handler) =>
    NotificationPreferencesService(client: MockClient(handler), token: () => 'user-token');

/// A tall phone-sized surface, so the whole settings list is built.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('loads the saved settings and the server channel status', (tester) async {
    useTallScreen(tester);
    final service = serviceWith((_) async => http.Response(jsonEncode(prefsJson(push: false, email: true, slack: true,
        updatedAt: '2026-11-18T08:00:00Z')), 200));
    await tester.pumpWidget(MaterialApp(home: S27NotificationPreferencesScreen(service: service)));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byKey(const Key('prefs-push'))).value, isFalse);
    expect(tester.widget<Switch>(find.byKey(const Key('prefs-email'))).value, isTrue);
    expect(find.text('Connected'), findsOneWidget); // Slack
    expect(find.text('Not set up'), findsOneWidget); // Discord
    expect(find.textContaining('Saved 2026-11-18'), findsOneWidget);
  });

  testWidgets('saving a switch sends both flags with the user token', (tester) async {
    useTallScreen(tester);
    final requests = <http.Request>[];
    final service = serviceWith((request) async {
      requests.add(request);
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(prefsJson(push: body['push_enabled'], email: body['email_enabled'],
            updatedAt: '2026-11-18T09:00:00Z')), 200);
      }
      return http.Response(jsonEncode(prefsJson()), 200);
    });
    await tester.pumpWidget(MaterialApp(home: S27NotificationPreferencesScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.textContaining('defaults are shown'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prefs-email')));
    await tester.pumpAndSettle();

    final put = requests.last;
    expect(put.method, 'PUT');
    expect(put.url.path, '/api/notifications/preferences');
    expect(put.headers['Authorization'], 'Bearer user-token');
    expect(jsonDecode(put.body), {'push_enabled': true, 'email_enabled': true});
    expect(tester.widget<Switch>(find.byKey(const Key('prefs-email'))).value, isTrue);
    expect(find.textContaining('Saved 2026-11-18'), findsOneWidget);
  });

  testWidgets('a failed save puts the switch back and shows why', (tester) async {
    final service = serviceWith((request) async => request.method == 'PUT'
        ? http.Response(jsonEncode({'success': false, 'message': 'Failed to save notification preferences.'}), 500)
        : http.Response(jsonEncode(prefsJson()), 200));
    await tester.pumpWidget(MaterialApp(home: S27NotificationPreferencesScreen(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('prefs-push')));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byKey(const Key('prefs-push'))).value, isTrue);
    expect(find.text('Failed to save notification preferences.'), findsOneWidget);
  });

  testWidgets('shows a retry when the settings cannot be loaded', (tester) async {
    var calls = 0;
    final service = serviceWith((_) async {
      calls++;
      return calls == 1
          ? http.Response(jsonEncode({'success': false, 'message': 'Failed to load notification preferences.'}), 500)
          : http.Response(jsonEncode(prefsJson()), 200);
    });
    await tester.pumpWidget(MaterialApp(home: S27NotificationPreferencesScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Failed to load notification preferences.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prefs-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('prefs-push')), findsOneWidget);
  });

  test('an expired session gives a clear message', () async {
    final service = serviceWith((_) async => http.Response('{}', 401));
    expect(() => service.load(), throwsA(predicate((e) => e.toString().contains('sign in again'))));
  });
}
