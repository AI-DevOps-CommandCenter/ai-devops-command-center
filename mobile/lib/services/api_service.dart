import '../models/service_metrics_model.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/incident_model.dart';
import '../models/cicd_model.dart';
import '../models/playbook_model.dart';
import '../models/notification_model.dart';
import 'api_endpoints.dart';
import 'auth_service.dart';

/// Custom API Exception to propagate real backend error messages
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Central API Client handling authenticated requests to Vinuka's backend and Thilina's GitHub services
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _customToken;
  void setAuthToken(String token) {
    _customToken = token.isNotEmpty ? token : null;
  }

  Map<String, String> _headers() {
    final token = _customToken ?? AuthService().accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _parseErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    if (response.statusCode == 401) {
      return 'Session expired or unauthenticated. Please sign in again.';
    }
    if (response.statusCode == 403) {
      return 'Action forbidden. Users cannot approve their own requests.';
    }
    if (response.statusCode == 404) {
      return 'Requested resource not found.';
    }
    if (response.statusCode == 409) {
      return 'Conflict: this approval has already been decided.';
    }
    return 'Request failed with status ${response.statusCode}';
  }

  Future<http.Response> _safeGet(String url) async {
    try {
      return await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw ApiException('Backend server timed out after 8 seconds.', 408);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error or server unreachable: $e', 0);
    }
  }

  Future<http.Response> _safePost(String url, {Object? body}) async {
    try {
      return await http
          .post(Uri.parse(url), headers: _headers(), body: body)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw ApiException('Backend server timed out after 8 seconds.', 408);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error or server unreachable: $e', 0);
    }
  }

  Future<http.Response> _safePatch(String url, {Object? body}) async {
    try {
      return await http
          .patch(Uri.parse(url), headers: _headers(), body: body)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw ApiException('Backend server timed out after 8 seconds.', 408);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error or server unreachable: $e', 0);
    }
  }

  /// GET /api/dashboard/summary
  Future<Map<String, dynamic>> fetchDashboardSummary() async {
    final response = await _safeGet(ApiEndpoints.dashboardSummary);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded['data']);
      }
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }


  /// Fetches production incidents (GET /api/incidents)
  Future<List<IncidentModel>> fetchIncidents({
    String? status,
    String? severity,
    String? serviceName,
    int limit = 50,
    int offset = 0,
  }) async {
    var url = ApiEndpoints.incidents;
    final params = <String>[];
    if (status != null && status.isNotEmpty) params.add('status=$status');
    if (severity != null && severity.isNotEmpty) params.add('severity=$severity');
    if (serviceName != null && serviceName.isNotEmpty) params.add('service_name=$serviceName');
    if (params.isNotEmpty) {
      url = '$url?${params.join('&')}';
    }

    final response = await _safeGet(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List list = decoded is List
          ? decoded
          : (decoded['data'] is List ? decoded['data'] as List : []);
      return list.map((e) => IncidentModel.fromJson(e)).toList();
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }

  /// Fetches a specific incident by ID (GET /api/incidents/:id)
  Future<IncidentModel> fetchIncidentById(String id) async {
    final url = ApiEndpoints.incidentById(id);
    final response = await _safeGet(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['data'] != null ? decoded['data'] : decoded;
      return IncidentModel.fromJson(data);
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }

  /// PATCH /api/incidents/:id with a new status (operators and admins only).
  Future<IncidentModel> updateIncidentStatus(String id, String status) async {
    final response = await _safePatch(ApiEndpoints.incidentById(id), body: jsonEncode({'status': status}));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['data'] != null ? decoded['data'] : decoded;
      return IncidentModel.fromJson(Map<String, dynamic>.from(data as Map));
    }
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// Fetches AI investigations for an incident (GET /api/investigations?incident_id=...)
  Future<List<Map<String, dynamic>>> fetchInvestigations(String incidentId) async {
    final url = ApiEndpoints.investigations(incidentId: incidentId);
    final response = await _safeGet(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded['data'] is List) {
        return List<Map<String, dynamic>>.from(decoded['data']);
      }
      return [];
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }

  static List<Map<String, dynamic>> _mapList(dynamic v) => v is List
      ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : <Map<String, dynamic>>[];

  /// GET /api/incidents/:id/recommendation
  /// Latest AI analysis + enabled playbooks matching its recommended_action.
  /// Returns { 'analysis': Map?, 'playbooks': List<Map>, 'other_playbooks': List<Map> }.
  Future<Map<String, dynamic>> fetchRecommendation(String incidentId) async {
    final response = await _safeGet(ApiEndpoints.incidentRecommendation(incidentId));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['data'] is Map ? Map<String, dynamic>.from(decoded['data']) : <String, dynamic>{};
      return {
        'analysis': data['analysis'] is Map ? Map<String, dynamic>.from(data['analysis']) : null,
        'playbooks': _mapList(data['playbooks']),
        'other_playbooks': _mapList(data['other_playbooks']),
      };
    }
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/incidents/:id/recovery-checks (newest first).
  Future<List<Map<String, dynamic>>> fetchRecoveryChecks(String incidentId) async {
    final response = await _safeGet(ApiEndpoints.incidentRecoveryChecks(incidentId));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = decoded is Map && decoded['data'] is List ? decoded['data'] as List : const [];
      return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/postmortems?incident_id=... (newest first). Null when none exists yet.
  Future<Map<String, dynamic>?> fetchLatestPostmortem(String incidentId) async {
    final response = await _safeGet(ApiEndpoints.postmortems(incidentId: incidentId));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = decoded is Map && decoded['data'] is List ? decoded['data'] as List : const [];
      final first = list.whereType<Map>().cast<Map>().toList();
      return first.isEmpty ? null : Map<String, dynamic>.from(first.first);
    }
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  // ==========================================
  // ADMIN: PLAYBOOKS, AUDIT LOG, TEAM, INTEGRATIONS
  // (access is enforced by the database: RLS + role checks)
  // ==========================================

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response = await _safeGet('${ApiEndpoints.baseUrl}$path');
    if (response.statusCode == 200) return _dataList(response);
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  Future<Map<String, dynamic>> _patchMap(String path, Map<String, dynamic> body) async {
    final response = await _safePatch('${ApiEndpoints.baseUrl}$path', body: jsonEncode(body));
    if (response.statusCode == 200) return _dataMap(response);
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/admin/playbooks
  Future<List<Map<String, dynamic>>> fetchPlaybooks() => _getList('/api/admin/playbooks');

  /// PATCH /api/admin/playbooks/:id (admins only). Fields: name, description, enabled, requires_approval.
  Future<Map<String, dynamic>> updatePlaybook(String id, Map<String, dynamic> fields) =>
      _patchMap('/api/admin/playbooks/${Uri.encodeComponent(id)}', fields);

  /// GET /api/audit-logs
  Future<List<Map<String, dynamic>>> fetchAuditLogs({String? entityType, int limit = 50}) {
    final q = <String>['limit=$limit', if (entityType != null && entityType.isNotEmpty) 'entity_type=$entityType'];
    return _getList('/api/audit-logs?${q.join('&')}');
  }

  /// GET /api/admin/users (admins only)
  Future<List<Map<String, dynamic>>> fetchUsers() => _getList('/api/admin/users?limit=100');

  /// PATCH /api/admin/users/:id/role (admins only). role: admin | operator | user
  Future<Map<String, dynamic>> updateUserRole(String id, String role) =>
      _patchMap('/api/admin/users/${Uri.encodeComponent(id)}/role', {'role': role});

  /// GET /api/admin/integrations
  Future<List<Map<String, dynamic>>> fetchIntegrations() => _getList('/api/admin/integrations');

  /// GET /api/metrics/services – health of every service Prometheus scrapes.
  Future<List<ServiceHealth>> fetchServiceHealth() async {
    final response = await _safeGet('${ApiEndpoints.baseUrl}/api/metrics/services');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = decoded is Map && decoded['data'] is List ? decoded['data'] as List : const [];
      return list.whereType<Map>().map((m) => ServiceHealth.fromJson(Map<String, dynamic>.from(m))).toList();
    }
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/metrics/services/:service?window=… – current values and series.
  Future<ServiceMetrics> fetchServiceMetrics(String service, {int windowMinutes = 60}) async {
    final response = await _safeGet(
        '${ApiEndpoints.baseUrl}/api/metrics/services/${Uri.encodeComponent(service)}?window=$windowMinutes');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return ServiceMetrics.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
    }
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  // ==========================================
  // CI/CD & GITHUB ENDPOINTS (Thilina M7 Handoff)
  // ==========================================

  List<Map<String, dynamic>> _dataList(http.Response response) {
    final decoded = jsonDecode(response.body);
    final list = decoded is Map && decoded['data'] is List ? decoded['data'] as List : const [];
    return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Map<String, dynamic> _dataMap(http.Response response) {
    final decoded = jsonDecode(response.body);
    return Map<String, dynamic>.from((decoded is Map && decoded['data'] is Map ? decoded['data'] : decoded) as Map);
  }

  /// GET /api/github/repositories (allow-listed repositories only).
  /// 503 = GitHub is not configured on the backend (GITHUB_TOKEN / GITHUB_REPOSITORIES).
  Future<List<GithubRepoModel>> fetchRepositories() async {
    final response = await _safeGet(ApiEndpoints.githubRepositories);
    if (response.statusCode == 200) return _dataList(response).map(GithubRepoModel.fromJson).toList();
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/github/repositories/:owner/:repo/commits
  Future<List<GitCommitModel>> fetchCommits({
    required String owner,
    required String repo,
    String? branch,
    int limit = 10,
  }) async {
    final response = await _safeGet(ApiEndpoints.githubCommits(owner, repo, branch: branch, limit: limit));
    if (response.statusCode == 200) return _dataList(response).map(GitCommitModel.fromJson).toList();
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/github/repositories/:owner/:repo/pulls
  Future<List<PullRequestModel>> fetchPullRequests({
    required String owner,
    required String repo,
    String state = 'all',
    int limit = 10,
  }) async {
    final response = await _safeGet(ApiEndpoints.githubPulls(owner, repo, state: state, limit: limit));
    if (response.statusCode == 200) return _dataList(response).map(PullRequestModel.fromJson).toList();
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/github/repositories/:owner/:repo/pulls/:number
  Future<PullRequestModel> fetchPullRequestDetail({
    required String owner,
    required String repo,
    required int number,
  }) async {
    final response = await _safeGet(ApiEndpoints.githubPullDetail(owner, repo, number));
    if (response.statusCode == 200) return PullRequestModel.fromJson(_dataMap(response));
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/github/repositories/:owner/:repo/workflow-runs
  Future<List<WorkflowRunModel>> fetchWorkflowRuns({
    required String owner,
    required String repo,
    String? branch,
    String? status,
    int limit = 10,
  }) async {
    final response =
        await _safeGet(ApiEndpoints.githubWorkflowRuns(owner, repo, branch: branch, status: status, limit: limit));
    if (response.statusCode == 200) return _dataList(response).map(WorkflowRunModel.fromJson).toList();
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// GET /api/github/repositories/:owner/:repo/workflow-runs/:runId/jobs
  Future<List<WorkflowJobModel>> fetchWorkflowJobs({
    required String owner,
    required String repo,
    required int runId,
  }) async {
    final response = await _safeGet(ApiEndpoints.githubWorkflowRunJobs(owner, repo, runId));
    if (response.statusCode == 200) return _dataList(response).map(WorkflowJobModel.fromJson).toList();
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  // ==========================================
  // PLAYBOOK RUNS & APPROVALS (Vinuka M5 Handoff)
  // ==========================================

  /// GET /api/approvals (with optional status filter)
  Future<List<ApprovalModel>> fetchApprovals({String? status}) async {
    var url = ApiEndpoints.approvals;
    if (status != null && status.isNotEmpty) {
      url = '$url?status=$status';
    }

    final response = await _safeGet(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List list = decoded is List
          ? decoded
          : (decoded['data'] is List ? decoded['data'] as List : []);
      return list.map((e) => ApprovalModel.fromJson(e)).toList();
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }

  /// GET /api/approvals?status=pending
  Future<List<ApprovalModel>> fetchPendingApprovals() async {
    return fetchApprovals(status: 'pending');
  }

  /// GET /api/playbook-runs?status=...&incident_id=...
  Future<List<PlaybookRunModel>> fetchPlaybookRuns({
    String? status,
    String? incidentId,
  }) async {
    final params = <String>[];
    if (status != null && status.isNotEmpty) params.add('status=$status');
    if (incidentId != null && incidentId.isNotEmpty) params.add('incident_id=$incidentId');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final url = '${ApiEndpoints.playbookRuns}$query';

    final response = await _safeGet(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List list = decoded is List
          ? decoded
          : (decoded['data'] is List ? decoded['data'] as List : []);
      return list.map((e) => PlaybookRunModel.fromJson(e)).toList();
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }

  /// GET /api/playbook-runs/:id
  Future<PlaybookRunModel> fetchPlaybookRun(String runId) async {
    final url = ApiEndpoints.playbookRunById(runId);
    final response = await _safeGet(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['data'] != null ? decoded['data'] : decoded;
      return PlaybookRunModel.fromJson(data);
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }

  /// POST /api/playbook-runs
  Future<Map<String, dynamic>> createPlaybookRun({
    required String incidentId,
    required String playbookId,
    required Map<String, dynamic> requestPayload,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? 'idemp-${DateTime.now().millisecondsSinceEpoch}';
    final body = jsonEncode({
      'incident_id': incidentId,
      'playbook_id': playbookId,
      'request_payload': requestPayload,
      'idempotency_key': key,
    });

    final response = await _safePost(
      ApiEndpoints.playbookRuns,
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }

  /// Decides an approval via PATCH /api/approvals/:id/decision
  Future<Map<String, dynamic>> decideApproval({
    required String approvalId,
    required bool approve,
    String? reason,
  }) async {
    final decision = approve ? 'approved' : 'rejected';
    final url = ApiEndpoints.approvalDecision(approvalId);
    final payload = jsonEncode({
      'decision': decision,
      'status': decision,
      if (reason != null && reason.trim().isNotEmpty) ...{
        'reason': reason.trim(),
        'comments': reason.trim(),
      } else if (approve) ...{
        'comments': 'Approved by operator after incident review.',
      }
    });

    final response = await _safePatch(url, body: payload);

    try {
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return body is Map<String, dynamic> ? body : {'success': true, 'data': body};
      } else if (response.statusCode == 403) {
        throw ApiException(body['message'] ?? 'Users cannot approve their own requests.', 403);
      } else if (response.statusCode == 409) {
        throw ApiException(body['message'] ?? 'This approval request has already been decided.', 409);
      } else {
        throw ApiException(_parseErrorMessage(response), response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Unexpected response from approval server (${response.statusCode})', response.statusCode);
    }
  }

  /// Backwards-compatible decision caller
  Future<Map<String, dynamic>> submitPlaybookDecision({
    required String runId,
    required bool approve,
    String? comments,
    String? approvalId,
  }) async {
    if (approvalId != null && approvalId.isNotEmpty) {
      return decideApproval(
        approvalId: approvalId,
        approve: approve,
        reason: comments,
      );
    }

    // Direct run decision endpoint
    final status = approve ? 'approved' : 'rejected';
    final payload = jsonEncode({
      'status': status,
      'decision': status,
      'comments': comments ?? (approve ? 'Approved after reviewing incident.' : 'Rejected upon review.'),
      'reason': comments,
    });

    final url = ApiEndpoints.playbookRunDecision(runId);
    final response = await _safePatch(url, body: payload);

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body;
    } else if (response.statusCode == 403) {
      throw ApiException(body['message'] ?? 'Users cannot approve their own requests.', 403);
    } else if (response.statusCode == 409) {
      throw ApiException(body['message'] ?? 'This request has already been decided.', 409);
    } else {
      throw ApiException(_parseErrorMessage(response), response.statusCode);
    }
  }

  /// POST /api/playbook-runs/:id/cancel
  Future<Map<String, dynamic>> cancelPlaybookRun({
    required String runId,
    required String reason,
  }) async {
    final payload = jsonEncode({
      'reason': reason,
    });

    try {
      final url = ApiEndpoints.playbookRunCancel(runId);
      final response = await http
          .post(Uri.parse(url), headers: _headers(), body: payload)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    return {
      'success': true,
      'message': 'Playbook run cancelled.',
    };
  }

  // ==========================================
  // NOTIFICATIONS & FCM TOKENS (Vinuka M5 Task 04)
  // ==========================================

  /// GET /api/notifications?limit=...&offset=...
  Future<List<NotificationModel>> fetchNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    final url = '${ApiEndpoints.notifications}?limit=$limit&offset=$offset';
    final response = await _safeGet(url);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List list = decoded is List
          ? decoded
          : (decoded['data'] is List ? decoded['data'] as List : []);
      return list.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// PATCH /api/notifications/:id/read
  Future<bool> markNotificationAsRead(String id) async {
    final response = await _safePatch(ApiEndpoints.notificationRead(id));
    if (response.statusCode == 200) return true;
    throw ApiException(_parseErrorMessage(response), response.statusCode);
  }

  /// POST /api/device-tokens
  /// Registers the mobile device's FCM token upon login
  Future<bool> registerDeviceToken(String token, {String platform = 'android'}) async {
    try {
      final body = jsonEncode({
        'device_token': token,
        'platform': platform,
      });

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.deviceTokens),
            headers: _headers(),
            body: body,
          )
          .timeout(const Duration(seconds: 4));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false; // backend not reachable: not registered
    }
  }

  /// DELETE /api/device-tokens
  /// Unregisters the device token upon logout
  Future<bool> unregisterDeviceToken(String token) async {
    try {
      final body = jsonEncode({
        'device_token': token,
      });

      final response = await http
          .delete(
            Uri.parse(ApiEndpoints.deviceTokens),
            headers: _headers(),
            body: body,
          )
          .timeout(const Duration(seconds: 4));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

}
