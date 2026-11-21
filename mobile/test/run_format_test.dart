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

  test('remediationOutcomes: one result per run, oldest first', () {
    final names = {'run-scale': 'Scale sample-app', 'run-rollback': 'Roll back sample-app'};
    expect(
      remediationOutcomes([_healthy, _unhealthy], names),
      'Scale sample-app: peak 50.4%, not recovered → Roll back sample-app: 0%, recovered',
    );
    expect(remediationOutcomes([_healthy], const {}), 'Remediation: 0%, recovered');
    expect(remediationOutcomes(const [], names), isNull);
    expect(lastErrorRate(_healthy), 0);
  });

  test('peakErrorRate across checks', () {
    expect(peakErrorRate([_healthy, _unhealthy]), closeTo(0.504, 0.001));
    expect(peakErrorRate(const []), isNull);
    expect(formatErrorRate(0.5040221893453085), '50.4%');
    expect(formatErrorRate(0.0174), '1.7%');
  });

  group('readableText', () {
    final day = DateTime.parse('2026-11-21T08:42:36.234Z');
    // Expected values use the machine's time zone, so the test runs anywhere.
    final local = localTime('2026-11-21T08:42:36.234Z');

    test('ISO UTC times become local times on the same day', () {
      expect(readableText('Detected at 2026-11-21T08:42:36.234Z.', day: day), 'Detected at $local.');
      expect(readableText('deployed 2026-11-21T08:39:48.08704+00:00', day: day),
          'deployed ${localTime('2026-11-21T08:39:48.08704+00:00')}');
    });

    test('a time on another day keeps its date', () {
      expect(readableText('at 2026-11-19T08:42:36Z', day: day), 'at ${localDateTime('2026-11-19T08:42:36Z')}');
    });

    test('bare UTC times use the given day', () {
      expect(readableText('from 08:42:36.234Z to 08:50Z', day: day),
          'from $local to ${localTime('2026-11-21T08:50:00Z').substring(0, 5)}');
      expect(readableText('from 08:42:36Z'), 'from 08:42:36Z'); // no day: unchanged
    });

    test('error-rate ratios become percentages', () {
      expect(readableText('error_rate metric abnormal: current 0.502868068833652 (source: prometheus)'),
          'error_rate metric abnormal: current 50.3% (source: prometheus)');
      expect(readableText('Error rate 0.05, baseline 0.0'), 'Error rate 5%, baseline 0%');
      expect(readableText('error rate 50.3% already'), 'error rate 50.3% already');
    });

    test('other numbers are not changed', () {
      expect(readableText('confidence 0.75; error_rate 0.5'), 'confidence 0.75; error_rate 50%');
      expect(readableText('version 2.1 and 0.5 CPU'), 'version 2.1 and 0.5 CPU');
      expect(readableText('error rate high. Took 0.5 s'), 'error rate high. Took 0.5 s');
    });

    test('null and empty', () {
      expect(readableText(null), '');
      expect(readableText(''), '');
    });
  });
}
