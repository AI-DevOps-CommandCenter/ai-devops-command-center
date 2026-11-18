import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/run_format.dart';

// Shape stored by workflow 07 (recovery_checks.details), from the 18 Nov
// rollback run.
final _healthy = <String, dynamic>{
  'playbook_run_id': 'run-rollback',
  'status': 'healthy',
  'checked_at': '2026-11-18T08:52:49.251456+00:00',
  'details': {
    'verdict': 'recovered',
    'checks': [
      {
        'attempt': 1,
        'at': '2026-11-18T08:51:48.669Z',
        'results': [
          {'ok': true, 'name': 'up', 'value': 1, 'healthy': true, 'threshold': null},
          {'ok': true, 'name': 'error_rate', 'value': 0.17416816544793046, 'healthy': false, 'threshold': 0.05},
        ],
      },
      {
        'attempt': 2,
        'at': '2026-11-18T08:52:48.761Z',
        'results': [
          {'ok': true, 'name': 'up', 'value': 1, 'healthy': true, 'threshold': null},
          {'ok': true, 'name': 'error_rate', 'value': 0, 'healthy': true, 'threshold': 0.05},
        ],
      },
    ],
  },
};

final _unhealthy = <String, dynamic>{
  'playbook_run_id': 'run-scale',
  'status': 'unhealthy',
  'checked_at': '2026-11-18T07:49:34.830282+00:00',
  'details': {
    'checks': [
      {
        'attempt': 1,
        'at': '2026-11-18T07:47:34.655Z',
        'results': [
          {'ok': true, 'name': 'error_rate', 'value': 0.5040221893453085, 'healthy': false, 'threshold': 0.05},
          {'ok': false, 'name': 'up', 'healthy': null, 'error': 'no_data'},
        ],
      },
    ],
  },
};

void main() {
  test('incidentNumber builds INC-XXXXXXXX and keeps INC- ids', () {
    expect(incidentNumber('5faa19d5-53f5-46f1-b53d-ae9904da0704'), 'INC-5FAA19D5');
    expect(incidentNumber('INC-42'), 'INC-42');
    expect(incidentNumber(null), 'Incident');
    expect(incidentNumber(''), 'Incident');
  });

  test('local time and date formats', () {
    final t = DateTime(2026, 11, 18, 13, 11, 52);
    expect(localTime(t), '13:11:52');
    expect(localDate(t), '18 Nov 2026');
    expect(localDateTime(t), '18 Nov 2026, 13:11:52');
    expect(localTime('not a time'), 'not a time');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(hours: 1, minutes: 11, seconds: 3)), '1 h 11 min');
    expect(formatDuration(const Duration(minutes: 4, seconds: 12)), '4 min 12 s');
    expect(formatDuration(const Duration(seconds: 45)), '45 s');
  });

  test('recoveryCheckForRun only matches the given run', () {
    final checks = [_unhealthy, _healthy];
    expect(recoveryCheckForRun(checks, 'run-rollback')?['status'], 'healthy');
    expect(recoveryCheckForRun(checks, 'run-scale')?['status'], 'unhealthy');
    expect(recoveryCheckForRun(checks, 'other-run'), isNull);
    expect(recoveryCheckForRun(checks, null), isNull);
  });

  test('isFinalRecoveryStatus', () {
    expect(isFinalRecoveryStatus('healthy'), isTrue);
    expect(isFinalRecoveryStatus('unhealthy'), isTrue);
    expect(isFinalRecoveryStatus('failed'), isTrue);
    expect(isFinalRecoveryStatus('pending'), isFalse);
    expect(isFinalRecoveryStatus(null), isFalse);
  });

  test('describeAttempt shows the measured values', () {
    final attempts = recoveryAttempts(_healthy);
    expect(attempts, hasLength(2));
    final first = describeAttempt(attempts.first);
    expect(first, startsWith('Attempt 1 · '));
    expect(first, contains('up 1 ✓'));
    expect(first, contains('error rate 17.4% (limit 5%) ✗'));
    expect(describeAttempt(attempts.last), contains('error rate 0% (limit 5%) ✓'));
  });

  test('describeResult for a missing measurement', () {
    final attempt = recoveryAttempts(_unhealthy).first;
    final text = describeAttempt(attempt);
    expect(text, contains('error rate 50.4% (limit 5%) ✗'));
    expect(text, contains('up: no_data'));
  });

  test('peakErrorRate across checks', () {
    expect(peakErrorRate([_healthy, _unhealthy]), closeTo(0.504, 0.001));
    expect(peakErrorRate(const []), isNull);
    expect(formatErrorRate(0.5040221893453085), '50.4%');
    expect(formatErrorRate(0.0174), '1.7%');
  });
}
