import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';
import 'api_service.dart' show ApiException;
import 'auth_service.dart';

/// Which channels the backend itself can send to (set on the server, not per user).
class ServerChannels {
  final bool push;
  final bool email;
  final bool slack;
  final bool discord;
  const ServerChannels({this.push = false, this.email = false, this.slack = false, this.discord = false});

  factory ServerChannels.fromJson(Map<String, dynamic>? json) => ServerChannels(
        push: json?['push'] == true,
        email: json?['email'] == true,
        slack: json?['slack'] == true,
        discord: json?['discord'] == true,
      );
}

/// The signed-in user's notification settings (S27). In-app is always on.
class NotificationPreferences {
  final bool pushEnabled;
  final bool emailEnabled;
  final DateTime? updatedAt;
  final ServerChannels server;
  const NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    this.updatedAt,
    this.server = const ServerChannels(),
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) => NotificationPreferences(
        pushEnabled: json['push_enabled'] != false,
        emailEnabled: json['email_enabled'] == true,
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
        server: ServerChannels.fromJson(json['server_channels'] as Map<String, dynamic>?),
      );

  NotificationPreferences copyWith({bool? pushEnabled, bool? emailEnabled}) => NotificationPreferences(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        updatedAt: updatedAt,
        server: server,
      );
}

/// GET/PUT /api/notifications/preferences.
class NotificationPreferencesService {
  final http.Client _client;
  final String? Function() _token;
  NotificationPreferencesService({http.Client? client, String? Function()? token})
      : _client = client ?? http.Client(),
        _token = token ?? (() => AuthService().accessToken);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token() != null) 'Authorization': 'Bearer ${_token()}',
      };

  Future<NotificationPreferences> load() async {
    final response = await _send(() => _client.get(Uri.parse(ApiEndpoints.notificationPreferences), headers: _headers));
    return _parse(response);
  }

  Future<NotificationPreferences> save({required bool pushEnabled, required bool emailEnabled}) async {
    final response = await _send(() => _client.put(
          Uri.parse(ApiEndpoints.notificationPreferences),
          headers: _headers,
          body: jsonEncode({'push_enabled': pushEnabled, 'email_enabled': emailEnabled}),
        ));
    return _parse(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw ApiException('The server did not answer in time.', 408);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('The server is not reachable. Check your connection.', 0);
    }
  }

  NotificationPreferences _parse(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}
    if (response.statusCode == 200 && body?['data'] is Map<String, dynamic>) {
      return NotificationPreferences.fromJson(body!['data'] as Map<String, dynamic>);
    }
    if (response.statusCode == 401) {
      throw ApiException('Your session has expired. Please sign in again.', 401);
    }
    throw ApiException(body?['message']?.toString() ?? 'Could not load the notification settings.', response.statusCode);
  }
}
