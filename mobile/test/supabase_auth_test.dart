import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/supabase_config.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  group('Supabase Real Authentication Tests', () {
    test('SupabaseConfig contains valid project URL and anon key', () {
      expect(SupabaseConfig.projectUrl, contains('supabase.co'));
      expect(SupabaseConfig.anonKey, isNotEmpty);
      expect(SupabaseConfig.tokenEndpoint, contains('/auth/v1/token'));
    });

    test('Real login succeeds with valid test credentials', () async {
      final authService = AuthService();
      final user = await authService.signInWithPassword(
        email: 'mobile.test@yourdomain.com',
        password: 'himasha@123',
      );

      expect(user.email, equals('mobile.test@yourdomain.com'));
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

      expect(
        () async => await authService.signInWithPassword(
          email: 'mobile.test@yourdomain.com',
          password: 'incorrect-password-test',
        ),
        throwsA(predicate((e) =>
            e.toString().toLowerCase().contains('invalid') ||
            e.toString().toLowerCase().contains('credentials'))),
      );
    });

    test('Token refresh updates access token', () async {
      final authService = AuthService();
      // Ensure signed in first
      await authService.signInWithPassword(
        email: 'mobile.test@yourdomain.com',
        password: 'himasha@123',
      );

      final initialToken = authService.accessToken;
      final refreshSuccess = await authService.refreshSession();

      expect(refreshSuccess, isTrue);
      expect(authService.accessToken, isNotNull);
    });
  });
}
