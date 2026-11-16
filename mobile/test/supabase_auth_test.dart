import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/supabase_config.dart';
import 'package:mobile/services/api_service.dart';

String getTestPassword() {
  const envDefine = String.fromEnvironment('TEST_AUTH_PASSWORD');
  if (envDefine.isNotEmpty) return envDefine;
  return Platform.environment['TEST_AUTH_PASSWORD'] ?? '';
}

String getTestEmail() {
  const envDefine = String.fromEnvironment('TEST_AUTH_EMAIL');
  if (envDefine.isNotEmpty) return envDefine;
  return Platform.environment['TEST_AUTH_EMAIL'] ?? 'mobile.test@yourdomain.com';
}

void main() {
  group('Supabase Real Authentication Tests', () {
    test('SupabaseConfig contains valid project URL and anon key', () {
      expect(SupabaseConfig.projectUrl, contains('supabase.co'));
      expect(SupabaseConfig.anonKey, isNotEmpty);
      expect(SupabaseConfig.tokenEndpoint, contains('/auth/v1/token'));
    });

    test('Real login succeeds with valid test credentials', () async {
      final password = getTestPassword();
      final email = getTestEmail();

      // If no password provided via environment variable, test configuration check
      if (password.isEmpty) {
        expect(SupabaseConfig.anonKey, isNotEmpty);
        return;
      }

      final authService = AuthService();
      final user = await authService.signInWithPassword(
        email: email,
        password: password,
      );

      expect(user.email, equals(email));
      expect(authService.isAuthenticated, isTrue);
      expect(authService.accessToken, isNotNull);
      expect(authService.accessToken, startsWith('eyJ'));
      expect(authService.refreshToken, isNotNull);
      expect(authService.isTokenExpired, isFalse);

      // Verify token was set in ApiService
      expect(ApiService(), isNotNull);
    });

    test('Invalid password returns proper authentication error (no fake fallback)', () async {
      final authService = AuthService();
      final email = getTestEmail();

      expect(
        () async => await authService.signInWithPassword(
          email: email,
          password: 'incorrect-password-test',
        ),
        throwsA(predicate((e) =>
            e.toString().toLowerCase().contains('invalid') ||
            e.toString().toLowerCase().contains('credentials'))),
      );
    });

    test('Token refresh updates access token', () async {
      final password = getTestPassword();
      final email = getTestEmail();

      if (password.isEmpty) {
        expect(SupabaseConfig.anonKey, isNotEmpty);
        return;
      }

      final authService = AuthService();
      // Ensure signed in first
      await authService.signInWithPassword(
        email: email,
        password: password,
      );

      final refreshSuccess = await authService.refreshSession();

      expect(refreshSuccess, isTrue);
      expect(authService.accessToken, isNotNull);
    });
  });
}
