import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/services/api_service.dart' show ApiException;
import 'package:mobile/services/developer_assistant_service.dart';
import 'package:mobile/widgets/explain_panel.dart';

final explanationJson = {
  'success': true,
  'data': {
    'meaning': 'The app could not connect to PostgreSQL.',
    'likely_causes': ['The database is not running'],
    'next_checks': ['Check that the database container is up'],
    'confidence': 0.8,
    'redacted_count': 2,
    'model': 'test-model',
  },
};

DeveloperAssistantService serviceWith(Future<http.Response> Function(http.Request) handler) =>
    DeveloperAssistantService(client: MockClient(handler), token: () => 'user-token');

Future<void> pumpPanel(WidgetTester tester, DeveloperAssistantService service) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ExplainPanel(service: service)))));
}

void main() {
  test('Explanation.fromJson reads every field and tolerates missing lists', () {
    final e = Explanation.fromJson(explanationJson['data'] as Map<String, dynamic>);
    expect(e.meaning, 'The app could not connect to PostgreSQL.');
    expect(e.likelyCauses, ['The database is not running']);
    expect(e.nextChecks, ['Check that the database container is up']);
    expect(e.confidence, 0.8);
    expect(e.redactedCount, 2);
    expect(e.model, 'test-model');

    final empty = Explanation.fromJson({'meaning': 'Not a log.'});
    expect(empty.likelyCauses, isEmpty);
    expect(empty.nextChecks, isEmpty);
    expect(empty.redactedCount, 0);
  });

  test('explain() posts the text with the user token', () async {
    late http.Request sent;
    final service = serviceWith((req) async {
      sent = req;
      return http.Response(jsonEncode(explanationJson), 200);
    });
    final e = await service.explain('connection refused');
    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/assistant/explain');
    expect(sent.headers['Authorization'], 'Bearer user-token');
    expect(jsonDecode(sent.body), {'text': 'connection refused'});
    expect(e.meaning, contains('PostgreSQL'));
  });

  test('explain() shows the server message for 429 and 503, and a session message for 401', () async {
    for (final (status, message) in [
      (429, 'Too many explanations. You can ask 10 times every 5 minutes.'),
      (503, 'The developer assistant is not configured: GROQ_API_KEY is missing in backend/.env.'),
    ]) {
      final service = serviceWith((_) async => http.Response(jsonEncode({'success': false, 'message': message}), status));
      await expectLater(
        service.explain('x'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', message).having((e) => e.statusCode, 'status', status)),
      );
    }
    final expired = serviceWith((_) async => http.Response('{}', 401));
    await expectLater(expired.explain('x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
  });

  testWidgets('the panel shows the explanation, the redacted count and "explanation only"', (tester) async {
    await pumpPanel(tester, serviceWith((_) async => http.Response(jsonEncode(explanationJson), 200)));

    await tester.enterText(find.byKey(const Key('explain-input')), 'psycopg2.OperationalError: connection refused');
    await tester.tap(find.byKey(const Key('explain-button')));
    await tester.pumpAndSettle();

    expect(find.text('WHAT IT MEANS'), findsOneWidget);
    expect(find.text('WHAT TO CHECK NEXT'), findsOneWidget);
    expect(find.textContaining('could not connect to PostgreSQL'), findsOneWidget);
    expect(find.textContaining('The database is not running'), findsOneWidget);
    expect(find.textContaining('Check that the database container is up'), findsOneWidget);
    expect(find.textContaining('2 secrets were removed before sending'), findsOneWidget);
    expect(find.text('Explanation only: nothing was run or changed.'), findsOneWidget);
  });

  testWidgets('the panel asks for text first and shows server errors', (tester) async {
    var calls = 0;
    await pumpPanel(tester, serviceWith((_) async {
      calls++;
      return http.Response(jsonEncode({'success': false, 'message': 'The developer assistant is not configured: GROQ_API_KEY is missing in backend/.env.'}), 503);
    }));

    await tester.tap(find.byKey(const Key('explain-button')));
    await tester.pump();
    expect(find.text('Paste a log snippet or an error message first.'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byKey(const Key('explain-input')), 'error');
    await tester.tap(find.byKey(const Key('explain-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('GROQ_API_KEY is missing'), findsOneWidget);
    expect(calls, 1);
  });
}
