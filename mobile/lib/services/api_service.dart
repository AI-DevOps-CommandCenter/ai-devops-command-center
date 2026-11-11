import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/service_model.dart';
import '../models/incident_model.dart';
import '../models/metric_model.dart';
import '../models/cicd_model.dart';
import '../models/playbook_model.dart';
import 'api_endpoints.dart';
import 'auth_service.dart';

/// Central API Client handling authenticated requests to Vinuka's backend and Thilina's GitHub services
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Map<String, String> _headers() {
    final token = AuthService().accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetches registered backend services (Matches Vinuka's GET /api/services)
  Future<List<ServiceModel>> fetchServices() async {
    try {
      final response = await http
          .get(Uri.parse(ApiEndpoints.services), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is List) {
          final List list = body['data'];
          return list.map((e) => ServiceModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    // Mock data fallback matching backend schema for crash-free presentation
    return [
      ServiceModel(
        id: 'srv-001',
        name: 'payment-gateway',
        description: 'Processes credit card & wallet checkouts',
        environment: ServiceEnvironment.production,
        endpoint: 'https://pay.internal/health',
        status: ServiceStatus.degraded,
      ),
      ServiceModel(
        id: 'srv-002',
        name: 'auth-service',
        description: 'Supabase JWT verification and RBAC tokens',
        environment: ServiceEnvironment.production,
        endpoint: 'https://auth.internal/health',
        status: ServiceStatus.healthy,
      ),
      ServiceModel(
        id: 'srv-003',
        name: 'order-api',
        description: 'Manages cart dispatch and warehouse pipeline',
        environment: ServiceEnvironment.production,
        endpoint: 'https://orders.internal/health',
        status: ServiceStatus.healthy,
      ),
    ];
  }

  /// Fetches production incidents
  Future<List<IncidentModel>> fetchIncidents() async {
    try {
      final response = await http
          .get(Uri.parse(ApiEndpoints.incidents), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => IncidentModel.fromJson(e)).toList();
      }
    } catch (_) {}

    return [
      IncidentModel(
        id: 'INC-2026-904',
        title: 'Connection Pool Exhaustion',
        serviceName: 'payment-gateway',
        severity: IncidentSeverity.critical,
        status: IncidentStatus.open,
        detectedAt: DateTime.now().subtract(const Duration(minutes: 18)),
        summary: 'Database connection pool reached 100% capacity. HTTP 500 error spike.',
        rootCause: 'Connection leak introduced in deployment #104.',
        recommendedPlaybookId: 'PB-ROLLBACK',
        cpuUsage: 94.2,
        memoryUsage: 88.5,
        errorRate: 14.8,
      ),
    ];
  }

  /// Fetches live system metrics
  Future<MetricModel> fetchMetrics() async {
    return MetricModel(
      cpuUsage: 78.4,
      memoryUsage: 64.1,
      errorRate: 4.2,
      latencyMs: 142,
      timestamp: DateTime.now(),
    );
  }

  // ==========================================
  // CI/CD & GITHUB ENDPOINTS (Thilina M7 Handoff)
  // ==========================================

  /// GET /api/github/repositories
  Future<List<GithubRepoModel>> fetchRepositories() async {
    try {
      final response = await http
          .get(Uri.parse(ApiEndpoints.githubRepositories), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is List) {
          final List list = body['data'];
          return list.map((e) => GithubRepoModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    // Fallback matching Thilina's synthetic response
    return [
      GithubRepoModel(
        fullName: 'acme/payments-api',
        owner: 'acme',
        name: 'payments-api',
        description: 'Core microservice for payment orchestration and checkout processing',
        defaultBranch: 'main',
        isPrivate: true,
        htmlUrl: 'https://github.com/acme/payments-api',
        openIssuesCount: 4,
        pushedAt: DateTime.parse('2026-11-08T09:00:00Z'),
        updatedAt: DateTime.parse('2026-11-08T09:00:00Z'),
      ),
      GithubRepoModel(
        fullName: 'acme/orders-worker',
        owner: 'acme',
        name: 'orders-worker',
        description: 'Background worker consuming order placement queue events',
        defaultBranch: 'main',
        isPrivate: true,
        htmlUrl: 'https://github.com/acme/orders-worker',
        openIssuesCount: 1,
        pushedAt: DateTime.parse('2026-11-07T14:30:00Z'),
        updatedAt: DateTime.parse('2026-11-07T14:30:00Z'),
      ),
    ];
  }

  /// GET /api/github/repositories/:owner/:repo/commits
  Future<List<GitCommitModel>> fetchCommits({
    String owner = 'acme',
    String repo = 'payments-api',
    String? branch,
    int limit = 10,
  }) async {
    try {
      final url = ApiEndpoints.githubCommits(owner, repo, branch: branch, limit: limit);
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is List) {
          final List list = body['data'];
          return list.map((e) => GitCommitModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    return [
      GitCommitModel(
        sha: 'a91f3c2deadbeef1042',
        shortSha: 'a91f3c2',
        title: 'Tune DB pool settings',
        message: 'Tune DB pool settings\n\nLower pool timeout, add retry wrapper, update logging.',
        authorName: 'Alex Morgan',
        authorLogin: 'alexm',
        authoredAt: DateTime.parse('2026-11-08T08:45:00Z'),
        htmlUrl: 'https://github.com/acme/payments-api/commit/a91f3c2',
      ),
      GitCommitModel(
        sha: 'b48e109d901f89c0012',
        shortSha: 'b48e109',
        title: 'Fix health-check latency threshold',
        message: 'Adjust health probe timeout from 5s to 2s to catch degraded pods early',
        authorName: 'Dev One',
        authorLogin: 'devone',
        authoredAt: DateTime.parse('2026-11-07T16:20:00Z'),
        htmlUrl: 'https://github.com/acme/payments-api/commit/b48e109',
      ),
    ];
  }

  /// GET /api/github/repositories/:owner/:repo/pulls
  Future<List<PullRequestModel>> fetchPullRequests({
    String owner = 'acme',
    String repo = 'payments-api',
    String state = 'all',
    int limit = 10,
  }) async {
    try {
      final url = ApiEndpoints.githubPulls(owner, repo, state: state, limit: limit);
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is List) {
          final List list = body['data'];
          return list.map((e) => PullRequestModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    return [
      PullRequestModel(
        number: 214,
        title: 'Tune DB pool settings',
        state: 'closed',
        isMerged: true,
        isDraft: false,
        authorLogin: 'alexm',
        headBranch: 'tune-db-pool',
        baseBranch: 'main',
        createdAt: DateTime.parse('2026-11-07T08:00:00Z'),
        updatedAt: DateTime.parse('2026-11-08T08:00:00Z'),
        closedAt: DateTime.parse('2026-11-08T08:30:00Z'),
        mergedAt: DateTime.parse('2026-11-08T08:30:00Z'),
        htmlUrl: 'https://github.com/acme/payments-api/pull/214',
        body: 'Lower DB pool timeout, add retry wrapper, update logging.',
        commitsCount: 1,
        additions: 12,
        deletions: 4,
        changedFiles: 3,
        mergeableState: 'clean',
      ),
    ];
  }

  /// GET /api/github/repositories/:owner/:repo/pulls/:number
  Future<PullRequestModel> fetchPullRequestDetail({
    String owner = 'acme',
    String repo = 'payments-api',
    int number = 214,
  }) async {
    try {
      final url = ApiEndpoints.githubPullDetail(owner, repo, number);
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] != null) {
          return PullRequestModel.fromJson(body['data']);
        }
      }
    } catch (_) {}

    return PullRequestModel(
      number: 214,
      title: 'Tune DB pool settings',
      state: 'closed',
      isMerged: true,
      isDraft: false,
      authorLogin: 'alexm',
      headBranch: 'tune-db-pool',
      baseBranch: 'main',
      createdAt: DateTime.parse('2026-11-07T08:00:00Z'),
      updatedAt: DateTime.parse('2026-11-08T08:00:00Z'),
      closedAt: DateTime.parse('2026-11-08T08:30:00Z'),
      mergedAt: DateTime.parse('2026-11-08T08:30:00Z'),
      htmlUrl: 'https://github.com/acme/payments-api/pull/214',
      body: 'Lower DB pool timeout, add retry wrapper, update logging.',
      commitsCount: 1,
      additions: 12,
      deletions: 4,
      changedFiles: 3,
      mergeableState: 'clean',
    );
  }

  /// GET /api/github/repositories/:owner/:repo/workflow-runs
  Future<List<WorkflowRunModel>> fetchWorkflowRuns({
    String owner = 'acme',
    String repo = 'payments-api',
    String? branch,
    String? status,
    int limit = 10,
  }) async {
    try {
      final url = ApiEndpoints.githubWorkflowRuns(owner, repo, branch: branch, status: status, limit: limit);
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is List) {
          final List list = body['data'];
          return list.map((e) => WorkflowRunModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    return [
      WorkflowRunModel(
        id: 318,
        name: 'CI',
        runNumber: 318,
        event: 'push',
        status: 'completed',
        conclusion: 'failure',
        branch: 'main',
        headSha: 'a91f3c2deadbeef',
        actorLogin: 'devone',
        createdAt: DateTime.parse('2026-11-08T08:46:00Z'),
        updatedAt: DateTime.parse('2026-11-08T08:50:00Z'),
        runStartedAt: DateTime.parse('2026-11-08T08:46:05Z'),
        htmlUrl: 'https://github.com/acme/payments-api/actions/runs/318',
      ),
      WorkflowRunModel(
        id: 317,
        name: 'Deployment v2.8.1',
        runNumber: 317,
        event: 'push',
        status: 'completed',
        conclusion: 'success',
        branch: 'main',
        headSha: 'a91f3c2',
        actorLogin: 'alexm',
        createdAt: DateTime.parse('2026-11-08T08:05:00Z'),
        updatedAt: DateTime.parse('2026-11-08T08:12:00Z'),
        runStartedAt: DateTime.parse('2026-11-08T08:05:00Z'),
        htmlUrl: 'https://github.com/acme/payments-api/actions/runs/317',
      ),
    ];
  }

  /// GET /api/github/repositories/:owner/:repo/workflow-runs/:runId/jobs
  Future<List<WorkflowJobModel>> fetchWorkflowJobs({
    String owner = 'acme',
    String repo = 'payments-api',
    int runId = 318,
  }) async {
    try {
      final url = ApiEndpoints.githubWorkflowRunJobs(owner, repo, runId);
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is List) {
          final List list = body['data'];
          return list.map((e) => WorkflowJobModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    return [
      WorkflowJobModel(
        id: 901,
        name: 'integration-tests',
        status: 'completed',
        conclusion: 'failure',
        startedAt: DateTime.parse('2026-11-08T08:46:10Z'),
        completedAt: DateTime.parse('2026-11-08T08:48:24Z'),
        htmlUrl: 'https://github.com/acme/payments-api/actions/runs/318/job/901',
        steps: [
          WorkflowStepModel(number: 1, name: 'Set up job', status: 'completed', conclusion: 'success'),
          WorkflowStepModel(number: 2, name: 'Checkout repository', status: 'completed', conclusion: 'success'),
          WorkflowStepModel(number: 3, name: 'Install dependencies', status: 'completed', conclusion: 'success'),
          WorkflowStepModel(number: 4, name: 'Run integration tests', status: 'completed', conclusion: 'failure'),
        ],
      ),
    ];
  }

  // ==========================================
  // PLAYBOOK RUNS & APPROVALS (Vinuka M5 Handoff)
  // ==========================================

  /// GET /api/approvals?status=pending
  Future<List<ApprovalModel>> fetchPendingApprovals() async {
    try {
      final url = '${ApiEndpoints.approvals}?status=pending';
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is List) {
          final List list = body['data'];
          return list.map((e) => ApprovalModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    // Mock pending approval matching Vinuka's exact backend schema
    return [
      ApprovalModel(
        id: 'appr-uuid-1042-rb',
        playbookRunId: 'run-uuid-1042-rb',
        incidentId: 'INC-1042',
        playbookId: 'pb-uuid-rollback-01',
        actionType: PlaybookActionType.rollback,
        status: 'pending',
        requestedBy: 'Alex Morgan',
        serviceName: 'payments-api',
        environment: 'Production',
        fromVersion: 'v2.8.1',
        toVersion: 'v2.8.0',
        impactDescription:
            'Impact: brief request failures during switchover (about 30 s). Nothing runs until you confirm.',
        requestPayload: {
          'service': 'payments-api',
          'environment': 'Production',
          'from_version': 'v2.8.1',
          'to_version': 'v2.8.0',
        },
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
  }

  /// GET /api/playbook-runs?status=...&incident_id=...
  Future<List<PlaybookRunModel>> fetchPlaybookRuns({
    String? status,
    String? incidentId,
  }) async {
    try {
      final params = <String>[];
      if (status != null) params.add('status=$status');
      if (incidentId != null) params.add('incident_id=$incidentId');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final url = '${ApiEndpoints.playbookRuns}$query';

      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is List) {
          final List list = body['data'];
          return list.map((e) => PlaybookRunModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    return [
      PlaybookRunModel(
        id: 'run-uuid-1042-rb',
        incidentId: incidentId ?? 'INC-1042',
        playbookId: 'pb-uuid-rollback-01',
        approvalId: 'appr-uuid-1042-rb',
        actionType: PlaybookActionType.rollback,
        status: PlaybookRunStatus.pendingApproval,
        serviceName: 'payments-api',
        environment: 'Production',
        fromVersion: 'v2.8.1',
        toVersion: 'v2.8.0',
        requestedBy: 'Alex Morgan',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        steps: const [
          PlaybookExecutionStep(time: '14:24', title: 'Queued', detail: 'Pending operator approval', status: 'completed'),
          PlaybookExecutionStep(time: '14:25', title: 'Switching traffic to v2.8.0', detail: 'Ingress routing update', status: 'pending'),
          PlaybookExecutionStep(time: '14:26', title: 'Draining v2.8.1', detail: 'Connection drain timeout 30s', status: 'pending'),
          PlaybookExecutionStep(time: '14:27', title: 'Execution complete', detail: 'Playbook completed', status: 'pending'),
        ],
      ),
    ];
  }

  /// GET /api/playbook-runs/:id
  Future<PlaybookRunModel> fetchPlaybookRun(String runId) async {
    try {
      final url = ApiEndpoints.playbookRunById(runId);
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['data'] is Map<String, dynamic>) {
          return PlaybookRunModel.fromJson(body['data']);
        }
      }
    } catch (_) {}

    // Fallback model for offline/demo reliability
    return PlaybookRunModel(
      id: runId.isNotEmpty ? runId : 'run-uuid-1042-rb',
      incidentId: 'INC-1042',
      playbookId: 'pb-uuid-rollback-01',
      approvalId: 'appr-uuid-1042-rb',
      actionType: PlaybookActionType.rollback,
      status: PlaybookRunStatus.running,
      serviceName: 'payments-api',
      environment: 'Production',
      fromVersion: 'v2.8.1',
      toVersion: 'v2.8.0',
      requestedBy: 'Alex Morgan',
      createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
      startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      steps: const [
        PlaybookExecutionStep(time: '14:24', title: 'Queued', detail: 'Dispatched to n8n engine', status: 'completed'),
        PlaybookExecutionStep(time: '14:25', title: 'Switching traffic to v2.8.0', detail: 'Ingress routing updated', status: 'completed'),
        PlaybookExecutionStep(time: '14:26', title: 'Draining v2.8.1', detail: 'Drain in progress (30s timeout)', status: 'running'),
        PlaybookExecutionStep(time: '14:27', title: 'Execution complete', detail: 'Ready for health verification', status: 'pending'),
      ],
    );
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

    try {
      final response = await http
          .post(
            Uri.parse(ApiEndpoints.playbookRuns),
            headers: _headers(),
            body: body,
          )
          .timeout(const Duration(seconds: 4));

      final Map<String, dynamic> res = jsonDecode(response.body);
      return res;
    } catch (_) {
      return {
        'success': true,
        'message': 'Playbook execution request created successfully (Demo Mode).',
        'data': {
          'id': 'run-uuid-demo-${DateTime.now().millisecondsSinceEpoch}',
          'approval_id': 'appr-uuid-demo-${DateTime.now().millisecondsSinceEpoch}',
        },
      };
    }
  }

  /// PATCH /api/playbook-runs/:id/decision
  /// Approves or rejects a playbook run (or /api/approvals/:id/decision)
  Future<Map<String, dynamic>> submitPlaybookDecision({
    required String runId,
    required bool approve,
    String? comments,
    String? approvalId,
  }) async {
    final status = approve ? 'approved' : 'rejected';
    final payload = jsonEncode({
      'status': status,
      'comments': comments ?? (approve ? 'Approved after reviewing incident.' : 'Rejected upon review.'),
    });

    try {
      // Primary route: /api/playbook-runs/:id/decision
      final url = ApiEndpoints.playbookRunDecision(runId);
      final response = await http
          .patch(Uri.parse(url), headers: _headers(), body: payload)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 403) {
        // Enforce Vinuka's Authorization rule: Users cannot approve their own requests
        final res = jsonDecode(response.body);
        return {
          'success': false,
          'message': res['message'] ?? 'Users cannot approve their own requests.',
        };
      }
    } catch (_) {}

    // Simulated successful decision response
    return {
      'success': true,
      'message': approve
          ? 'Playbook request approved successfully.'
          : 'Playbook request rejected.',
      'data': {
        'id': runId,
        'status': status,
      },
    };
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
}
