import 'package:flutter/foundation.dart';

/// Centralized API Endpoints Configuration
/// Matches Vinuka's Express backend running on Port 3000
class ApiEndpoints {
  // Support dynamic base URL via: --dart-define=API_BASE_URL=http://...
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Configurable host:
  // Environment override > Android Emulator 10.0.2.2 > Localhost 3000
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  // Dashboard summary endpoint (GET /api/dashboard/summary)
  static String get dashboardSummary => '$baseUrl/api/dashboard/summary';

  // Authentication & User Profile
  static String get me => '$baseUrl/api/me';
  static String get forgotPassword => '$baseUrl/api/auth/forgot-password';
  static String get authConfig => '$baseUrl/api/auth/config';

  // Services Management (Vinuka's routes)

  // Incidents & AI Investigation (Vinuka's routes)
  static String get incidents => '$baseUrl/api/incidents';
  static String incidentById(String id) => '$baseUrl/api/incidents/$id';
  static String investigations({String? incidentId}) => incidentId != null && incidentId.isNotEmpty
      ? '$baseUrl/api/investigations?incident_id=$incidentId'
      : '$baseUrl/api/investigations';
  static String investigationById(String id) => '$baseUrl/api/investigations/$id';
  static String incidentRecommendation(String id) => '$baseUrl/api/incidents/$id/recommendation';
  static String incidentRecoveryChecks(String id) => '$baseUrl/api/incidents/$id/recovery-checks';
  static String postmortems({String? incidentId}) => incidentId != null && incidentId.isNotEmpty
      ? '$baseUrl/api/postmortems?incident_id=$incidentId'
      : '$baseUrl/api/postmortems';

  // GitHub & CI/CD Pipelines (Thilina's routes - M7)
  static String get githubRepositories => '$baseUrl/api/github/repositories';
  static String githubRepo(String owner, String repo) =>
      '$baseUrl/api/github/repositories/$owner/$repo';
  static String githubCommits(String owner, String repo,
          {String? branch, int limit = 10}) =>
      '$baseUrl/api/github/repositories/$owner/$repo/commits?branch=${branch ?? ''}&limit=$limit';
  static String githubPulls(String owner, String repo,
          {String state = 'open', int limit = 10}) =>
      '$baseUrl/api/github/repositories/$owner/$repo/pulls?state=$state&limit=$limit';
  static String githubPullDetail(String owner, String repo, int number) =>
      '$baseUrl/api/github/repositories/$owner/$repo/pulls/$number';
  static String githubWorkflowRuns(String owner, String repo,
          {String? branch, String? status, int limit = 10}) =>
      '$baseUrl/api/github/repositories/$owner/$repo/workflow-runs?branch=${branch ?? ''}&status=${status ?? ''}&limit=$limit';
  static String githubWorkflowRunJobs(String owner, String repo, int runId) =>
      '$baseUrl/api/github/repositories/$owner/$repo/workflow-runs/$runId/jobs';

  // Notifications & Device Tokens (Vinuka's Backend API - M5 Handoff)
  static String get notifications => '$baseUrl/api/notifications';
  static String notificationRead(String id) => '$baseUrl/api/notifications/$id/read';
  static String get deviceTokens => '$baseUrl/api/device-tokens';
  static String get notificationPreferences => '$baseUrl/api/notifications/preferences';

  // Playbook Runs & Approvals (Vinuka's Backend API - M5 Handoff)
  static String get playbookRuns => '$baseUrl/api/playbook-runs';
  static String playbookRunById(String id) => '$baseUrl/api/playbook-runs/$id';
  static String playbookRunDecision(String id) => '$baseUrl/api/playbook-runs/$id/decision';
  static String playbookRunCancel(String id) => '$baseUrl/api/playbook-runs/$id/cancel';
  static String get approvals => '$baseUrl/api/approvals';
  static String approvalDecision(String id) => '$baseUrl/api/approvals/$id/decision';
}
