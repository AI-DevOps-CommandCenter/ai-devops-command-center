import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'api_endpoints.dart';
import 'api_service.dart';
import 'supabase_config.dart';

/// Real Supabase Authentication Service
/// Handles real Supabase email/password auth, access tokens, and auto-refresh
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  UserModel? _currentUser;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _accessToken != null;

  /// Check if the current access token has expired (or expiring in < 30 seconds)
  bool get isTokenExpired {
    if (_expiresAt == null) return true;
    return DateTime.now().isAfter(_expiresAt!.subtract(const Duration(seconds: 30)));
  }

  /// Sign in with real Supabase email and password
  /// Throws an [Exception] with exact Supabase error message if credentials are invalid.
  /// No fake fallback!
  Future<UserModel> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('Email and password are required.');
    }

    final url = Uri.parse('${SupabaseConfig.tokenEndpoint}?grant_type=password');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
      },
      body: jsonEncode({
        'email': cleanEmail,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 10));

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['access_token'] != null) {
      _accessToken = data['access_token'] as String;
      _refreshToken = data['refresh_token'] as String?;
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
      _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      // Inject the real Supabase access token into ApiService
      ApiService().setAuthToken(_accessToken!);

      final userData = data['user'] as Map<String, dynamic>? ?? {};
      final userId = userData['id']?.toString() ?? 'usr-${DateTime.now().millisecondsSinceEpoch}';
      final userEmail = userData['email']?.toString() ?? cleanEmail;
      final rawName = userEmail.split('@').first.replaceAll('.', ' ');
      final userName = rawName.isNotEmpty
          ? rawName[0].toUpperCase() + rawName.substring(1)
          : 'DevOps Operator';

      _currentUser = UserModel(
        id: userId,
        email: userEmail,
        name: userName,
        role: userData['role']?.toString() ?? 'authenticated',
        accessToken: _accessToken,
      );

      // Verify token with backend /api/me if backend is reachable
      try {
        final meResponse = await http.get(
          Uri.parse(ApiEndpoints.me),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
        ).timeout(const Duration(seconds: 6));

        if (meResponse.statusCode == 200) {
          final meData = jsonDecode(meResponse.body);
          _currentUser = UserModel.fromApiMe(meData, token: _accessToken);
        }
      } catch (_) {
        // Backend /api/me is optional or might be offline; Supabase user session remains verified
      }

      return _currentUser!;
    } else {
      // Return proper Supabase authentication error
      final errorMsg = data['msg'] ??
          data['message'] ??
          data['error_description'] ??
          data['error'] ??
          'Invalid login credentials.';
      throw Exception(errorMsg);
    }
  }

  /// Automatically refresh access token using Supabase refresh_token
  Future<bool> refreshSession() async {
    if (_refreshToken == null) return false;

    try {
      final url = Uri.parse('${SupabaseConfig.tokenEndpoint}?grant_type=refresh_token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          'refresh_token': _refreshToken,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _accessToken = data['access_token'] as String;
        _refreshToken = data['refresh_token'] as String? ?? _refreshToken;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        ApiService().setAuthToken(_accessToken!);
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Retrieves a valid Supabase access token, auto-refreshing if expired
  Future<String?> getValidAccessToken() async {
    if (_accessToken == null) return null;
    if (isTokenExpired) {
      final refreshed = await refreshSession();
      if (!refreshed) {
        signOut();
        return null;
      }
    }
    return _accessToken;
  }

  /// Sign out and clear real Supabase session
  Future<void> signOut() async {
    if (_accessToken != null) {
      try {
        await http.post(
          Uri.parse(SupabaseConfig.logoutEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer $_accessToken',
          },
        ).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _currentUser = null;
    ApiService().setAuthToken('');
  }
}
