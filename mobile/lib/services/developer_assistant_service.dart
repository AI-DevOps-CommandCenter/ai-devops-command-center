import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';
import 'api_service.dart' show ApiException;
import 'auth_service.dart';

/// The explanation of a pasted log snippet or error (S23 developer assistant).
class Explanation {
  final String meaning;
  final List<String> likelyCauses;
  final List<String> nextChecks;
  final double confidence;
  final int redactedCount;
  final String? model;

  const Explanation({
    required this.meaning,
    this.likelyCauses = const [],
    this.nextChecks = const [],
    this.confidence = 0,
    this.redactedCount = 0,
    this.model,
  });

  static List<String> _strings(Object? value) => value is List
      ? value
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
      : const [];

  factory Explanation.fromJson(Map<String, dynamic> json) => Explanation(
    meaning: json['meaning']?.toString() ?? '',
    likelyCauses: _strings(json['likely_causes']),
    nextChecks: _strings(json['next_checks']),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    redactedCount: (json['redacted_count'] as num?)?.toInt() ?? 0,
    model: json['model']?.toString(),
  );
}

/// POST /api/assistant/explain. The backend removes secrets before the text
/// goes to the AI; nothing is stored. The AI only explains.
class DeveloperAssistantService {
  static const int maxLength = 8000;

  final http.Client _client;
  final String? Function() _token;
  DeveloperAssistantService({http.Client? client, String? Function()? token})
    : _client = client ?? http.Client(),
      _token = token ?? (() => AuthService().accessToken);

  Future<Explanation> explain(String text) async {
    final token = _token();
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(ApiEndpoints.assistantExplain),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'text': text}),
          )
          // The AI can take a while; the backend gives up after 25 s.
          .timeout(const Duration(seconds: 35));
    } on TimeoutException {
      throw ApiException(
        'The assistant did not answer in time. Try again.',
        408,
      );
    } catch (_) {
      throw ApiException(
        'The server is not reachable. Check your connection.',
        0,
      );
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode == 200 && body?['data'] is Map<String, dynamic>) {
      return Explanation.fromJson(body!['data'] as Map<String, dynamic>);
    }
    if (response.statusCode == 401) {
      throw ApiException(
        'Your session has expired. Please sign in again.',
        401,
      );
    }
    throw ApiException(
      body?['message']?.toString() ?? 'Could not explain the text.',
      response.statusCode,
    );
  }
}
