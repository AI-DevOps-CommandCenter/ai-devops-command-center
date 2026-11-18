import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/screens/s29_forgot_password_screen.dart';
import 'package:mobile/screens/s29b_set_new_password_screen.dart';
import 'package:mobile/services/password_recovery.dart';

Widget wrap(Widget child) => MaterialApp(
      home: child,
      routes: {'/signin': (_) => const Scaffold(body: Text('SIGN IN'))},
    );

void main() {
  group('parseRecoveryLink', () {
    test('reads the recovery token from the fragment', () {
      final link = parseRecoveryLink(Uri.parse(
          'http://127.0.0.1:8080/#access_token=abc.def&expires_in=3600&refresh_token=r&token_type=bearer&type=recovery'));
      expect(link?.accessToken, 'abc.def');
    });

    test('accepts a leading slash (hash routing)', () {
      expect(parseRecoveryLink(Uri.parse('http://x/#/access_token=t&type=recovery'))?.accessToken, 't');
    });

    test('turns an expired link into a readable error', () {
      final link = parseRecoveryLink(Uri.parse(
          'http://x/#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired'));
      expect(link?.hasToken, isFalse);
      expect(link?.errorMessage, contains('expired'));
    });

    test('ignores normal app URLs and other tokens', () {
      expect(parseRecoveryLink(Uri.parse('http://x/')), isNull);
      expect(parseRecoveryLink(Uri.parse('http://x/#/dashboard')), isNull);
      expect(parseRecoveryLink(Uri.parse('http://x/#access_token=t&type=signup')), isNull);
    });
  });

  group('S29 forgot password', () {
    testWidgets('sends the email to the backend and shows the generic answer', (tester) async {
      http.Request? sent;
      final service = PasswordResetService(client: MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode({'message': 'If an account exists for this email, a password reset link has been sent.'}), 202);
      }));
      await tester.pumpWidget(wrap(S29ForgotPasswordScreen(service: service)));

      await tester.enterText(find.byKey(const Key('forgot-email')), ' user@example.test ');
      await tester.tap(find.byKey(const Key('forgot-send')));
      await tester.pumpAndSettle();

      expect(sent!.url.path, '/api/auth/forgot-password');
      expect(jsonDecode(sent!.body), {'email': 'user@example.test'});
      expect(find.text('Check your inbox'), findsOneWidget);
    });

    testWidgets('validates the email before calling the backend', (tester) async {
      var calls = 0;
      final service = PasswordResetService(client: MockClient((_) async {
        calls++;
        return http.Response('{}', 202);
      }));
      await tester.pumpWidget(wrap(S29ForgotPasswordScreen(service: service)));

      await tester.enterText(find.byKey(const Key('forgot-email')), 'nope');
      await tester.tap(find.byKey(const Key('forgot-send')));
      await tester.pump();

      expect(calls, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows the backend error (rate limit)', (tester) async {
      final service = PasswordResetService(client: MockClient((_) async =>
          http.Response(jsonEncode({'message': 'Too many reset emails. Please try again later.'}), 429)));
      await tester.pumpWidget(wrap(S29ForgotPasswordScreen(service: service)));

      await tester.enterText(find.byKey(const Key('forgot-email')), 'user@example.test');
      await tester.tap(find.byKey(const Key('forgot-send')));
      await tester.pumpAndSettle();

      expect(find.text('Too many reset emails. Please try again later.'), findsOneWidget);
    });
  });

  group('S29b set new password', () {
    testWidgets('sends the new password with the recovery token', (tester) async {
      http.Request? sent;
      final service = PasswordResetService(client: MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode({'message': 'ok'}), 200);
      }));
      await tester.pumpWidget(wrap(S29bSetNewPasswordScreen(link: const RecoveryLink.token('rec-token'), service: service)));

      await tester.enterText(find.byKey(const Key('reset-password')), 'new-password-1');
      await tester.enterText(find.byKey(const Key('reset-confirm')), 'new-password-1');
      await tester.tap(find.byKey(const Key('reset-save')));
      await tester.pumpAndSettle();

      expect(sent!.url.path, '/api/auth/reset-password');
      expect(sent!.headers['Authorization'], 'Bearer rec-token');
      expect(jsonDecode(sent!.body), {'password': 'new-password-1'});
      expect(find.text('Password changed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset-to-signin')));
      await tester.pumpAndSettle();
      expect(find.text('SIGN IN'), findsOneWidget);
    });

    testWidgets('checks length and that both passwords match', (tester) async {
      var calls = 0;
      final service = PasswordResetService(client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }));
      await tester.pumpWidget(wrap(S29bSetNewPasswordScreen(link: const RecoveryLink.token('t'), service: service)));

      await tester.enterText(find.byKey(const Key('reset-password')), 'short');
      await tester.tap(find.byKey(const Key('reset-save')));
      await tester.pump();
      expect(find.textContaining('at least 8'), findsWidgets);

      await tester.enterText(find.byKey(const Key('reset-password')), 'long-enough-1');
      await tester.enterText(find.byKey(const Key('reset-confirm')), 'long-enough-2');
      await tester.tap(find.byKey(const Key('reset-save')));
      await tester.pump();
      expect(find.text('The two passwords do not match.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('explains an expired link', (tester) async {
      await tester.pumpWidget(wrap(S29bSetNewPasswordScreen(
          link: const RecoveryLink.error('This reset link has expired or was already used. Request a new one.'))));
      expect(find.text('Reset link not valid'), findsOneWidget);
      expect(find.textContaining('expired'), findsOneWidget);
    });

    testWidgets('maps a rejected token to the expired-link message', (tester) async {
      final service = PasswordResetService(client: MockClient((_) async => http.Response('{"message":"x"}', 401)));
      await tester.pumpWidget(wrap(S29bSetNewPasswordScreen(link: const RecoveryLink.token('old'), service: service)));

      await tester.enterText(find.byKey(const Key('reset-password')), 'long-enough-1');
      await tester.enterText(find.byKey(const Key('reset-confirm')), 'long-enough-1');
      await tester.tap(find.byKey(const Key('reset-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('expired or was already used'), findsOneWidget);
    });
  });
}
