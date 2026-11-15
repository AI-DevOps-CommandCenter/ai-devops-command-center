import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/playbook_model.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  group('Playbook and Remediation Models Tests (Vinuka M5 Spec)', () {
    test('PlaybookActionType handles all 4 supported backend actions', () {
      expect(PlaybookActionType.fromString('restart'), PlaybookActionType.restart);
      expect(PlaybookActionType.fromString('rollback'), PlaybookActionType.rollback);
      expect(PlaybookActionType.fromString('scale'), PlaybookActionType.scale);
      expect(PlaybookActionType.fromString('circuit_breaker'), PlaybookActionType.circuitBreaker);
      expect(PlaybookActionType.fromString('circuitbreaker'), PlaybookActionType.circuitBreaker);

      expect(PlaybookActionType.restart.slug, 'restart');
      expect(PlaybookActionType.rollback.slug, 'rollback');
      expect(PlaybookActionType.scale.slug, 'scale');
      expect(PlaybookActionType.circuitBreaker.slug, 'circuit_breaker');
    });

    test('PlaybookRunStatus handles all backend and n8n statuses', () {
      expect(PlaybookRunStatus.fromString('pending_approval'), PlaybookRunStatus.pendingApproval);
      expect(PlaybookRunStatus.fromString('approved'), PlaybookRunStatus.approved);
      expect(PlaybookRunStatus.fromString('running'), PlaybookRunStatus.running);
      expect(PlaybookRunStatus.fromString('success'), PlaybookRunStatus.success);
      expect(PlaybookRunStatus.fromString('failed'), PlaybookRunStatus.failed);
      expect(PlaybookRunStatus.fromString('rejected'), PlaybookRunStatus.rejected);
      expect(PlaybookRunStatus.fromString('cancelled'), PlaybookRunStatus.cancelled);
    });

    test('ApprovalModel correctly parses Vinuka GET /api/approvals payload', () {
      final json = {
        'id': 'appr-uuid-999',
        'playbook_run_id': 'run-uuid-999',
        'incident_id': 'INC-1042',
        'action_type': 'rollback',
        'status': 'pending',
        'requested_by': 'Alex Morgan',
        'request_payload': {
          'service': 'payments-api',
          'environment': 'Production',
          'from_version': 'v2.8.1',
          'to_version': 'v2.8.0',
        },
      };

      final model = ApprovalModel.fromJson(json);
      expect(model.id, 'appr-uuid-999');
      expect(model.playbookRunId, 'run-uuid-999');
      expect(model.incidentId, 'INC-1042');
      expect(model.actionType, PlaybookActionType.rollback);
      expect(model.serviceName, 'payments-api');
      expect(model.fromVersion, 'v2.8.1');
      expect(model.toVersion, 'v2.8.0');
    });

    test('PlaybookRunModel correctly parses Vinuka GET /api/playbook-runs/:id payload', () {
      final json = {
        'id': 'run-uuid-777',
        'incident_id': 'INC-1042',
        'playbook_id': 'pb-rollback-01',
        'action_type': 'rollback',
        'status': 'running',
        'request_payload': {
          'service': 'payments-api',
        },
        'steps': [
          {'time': '14:24', 'title': 'Queued', 'detail': 'Queued', 'status': 'completed'},
          {'time': '14:25', 'title': 'Traffic shift', 'detail': 'Shift', 'status': 'running'},
        ],
      };

      final run = PlaybookRunModel.fromJson(json);
      expect(run.id, 'run-uuid-777');
      expect(run.status, PlaybookRunStatus.running);
      expect(run.actionType, PlaybookActionType.rollback);
      expect(run.steps.length, 2);
      expect(run.steps.first.title, 'Queued');
    });

    test('ApiService provides fallback approval and playbook data', () async {
      final api = ApiService();
      final approvals = await api.fetchPendingApprovals();
      expect(approvals.isNotEmpty, true);
      expect(approvals.first.serviceName, 'payments-api');

      final run = await api.fetchPlaybookRun('run-uuid-1042-rb');
      expect(run.actionType, PlaybookActionType.rollback);
      expect(run.steps.isNotEmpty, true);
    });
  });
}
