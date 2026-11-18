import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';

/// What the Supabase reset email link brought back to the app.
///
/// The link signs the user in and redirects to
/// `<PASSWORD_RESET_REDIRECT_URL>#access_token=…&type=recovery&…`, or, for an
/// expired or used link, `#error=access_denied&error_code=otp_expired&…`.
class RecoveryLink {
  final String? accessToken;
  final String? errorMessage;

  const RecoveryLink.token(String token)
      : accessToken = token,
        errorMessage = null;
  const RecoveryLink.error(String message)
      : accessToken = null,
        errorMessage = message;

  bool get hasToken => accessToken != null;
}

/// Reads a recovery link from the page URL (web). Returns null for any other URL.
RecoveryLink? parseRecoveryLink(Uri uri) {
  var fragment = uri.fragment;
  if (fragment.isEmpty) return null;
  // Hash routing may leave a leading "/" in front of the parameters.
  if (fragment.startsWith('/')) fragment = fragment.substring(1);
  if (!fragment.contains('=')) return null;

  final Map<String, String> params;
  try {
    params = Uri.splitQueryString(fragment);
  } catch (_) {
    return null;
  }

  if (params['type'] == 'recovery' && (params['access_token'] ?? '').isNotEmpty) {
    return RecoveryLink.token(params['access_token']!);
  }
  if (params.containsKey('error') || params.containsKey('error_code')) {
    final code = params['error_code'] ?? params['error'];
    final message = code == 'otp_expired'
        ? 'This reset link has expired or was already used. Request a new one.'
        : (params['error_description']?.replaceAll('+', ' ') ?? 'The reset link is not valid. Request a new one.');
    return RecoveryLink.error(message);
  }
  return null;
}

/// Holds the link found at startup until the "set new password" screen uses it.
class PasswordRecovery {
  static RecoveryLink? pending;

  static RecoveryLink? take() {
    final link = pending;
    pending = null;
    return link;
  }
}

class PasswordResetException implements Exception {
  final String message;
  final int? statusCode;
  PasswordResetException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// Calls the backend's public password-reset routes (backend/src/routes/auth.routes.ts).
class PasswordResetService {
  final http.Client _client;
  PasswordResetService({http.Client? client}) : _client = client ?? http.Client();

  /// POST /api/auth/forgot-password. Returns the backend's message; the answer
  /// is the same whether or not an account exists.
  Future<String> requestReset(String email) async {
    final response = await _post(ApiEndpoints.forgotPassword, {'email': email.trim()});
    if (response.statusCode == 202) return _message(response, 'If an account exists for this email, a reset link has been sent.');
    throw PasswordResetException(_message(response, 'Could not send the reset link. Try again later.'), response.statusCode);
  }

  /// POST /api/auth/reset-password with the recovery token from the email link.
  Future<String> setNewPassword(String recoveryToken, String password) async {
    final response = await _post(ApiEndpoints.resetPassword, {'password': password}, token: recoveryToken);
    if (response.statusCode == 200) return _message(response, 'Your password has been changed.');
    if (response.statusCode == 401) {
      throw PasswordResetException('This reset link has expired or was already used. Request a new one.', 401);
    }
    throw PasswordResetException(_message(response, 'Could not change the password. Try again later.'), response.statusCode);
  }

  Future<http.Response> _post(String url, Map<String, dynamic> body, {String? token}) async {
    try {
      return await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw PasswordResetException('The server is not reachable. Check your connection and try again.');
    }
  }

  String _message(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) return data['message'] as String;
    } catch (_) {}
    return fallback;
  }
}
