import 'package:flutter/foundation.dart';

/// Centralized API Endpoints Configuration
/// Matches Vinuka's Express backend running on Port 3000
class ApiEndpoints {
  // Configurable host:
  // Android Emulator uses 10.0.2.2, Web / Windows Desktop uses localhost
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  // Authentication & User Profile
  static String get me => '$baseUrl/api/me';
  static String get forgotPassword => '$baseUrl/api/auth/forgot-password';
  static String get authConfig => '$baseUrl/api/auth/config';

  // Services Management (Vinuka's routes)
  static String get services => '$baseUrl/api/services';
  static String serviceById(String id) => '$baseUrl/api/services/$id';

  // Incidents & AI Investigation
  static String get incidents => '$baseUrl/api/incidents';
  static String incidentById(String id) => '$baseUrl/api/incidents/$id';

  // Notifications (Himasha's Microservice - Port 5002 or via Gateway)
  static String get notifications => 'http://localhost:5002/api/notifications';
}
