// Shared helpers for the remediation screens (S05, S19, S20, S21): local
// times, short incident numbers and the values that workflow 07 stores in
// recovery_checks.details ({ verdict, checks: [{ attempt, at, results: [
// { name: up | error_rate, ok, value, threshold, healthy, error } ] }] }).

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

DateTime? parseTime(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// 13:11:52 (local time). Returns the input unchanged if it is not a time.
String localTime(dynamic value) {
  final t = parseTime(value);
  if (t == null) return value?.toString() ?? '';
  return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

/// 18 Nov 2026 (local date).
String localDate(dynamic value) {
  final t = parseTime(value);
  if (t == null) return value?.toString() ?? '';
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

/// 18 Nov 2026, 13:11:52
String localDateTime(dynamic value) {
  final t = parseTime(value);
  if (t == null) return value?.toString() ?? '';
  return '${localDate(t)}, ${localTime(t)}';
}

bool sameLocalDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "1 h 11 min", "4 min 12 s", "45 s"
String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
  return '${d.inSeconds} s';
}

/// INC-5FAA19D5 from a UUID; ids that already start with INC- are kept.
String incidentNumber(String? id, {String fallback = 'Incident'}) {
  if (id == null || id.isEmpty) return fallback;
  if (id.startsWith('INC-')) return id;
  return id.length > 8 ? 'INC-${id.substring(0, 8).toUpperCase()}' : id;
}

/// The newest recovery check stored for [runId], or null.
Map<String, dynamic>? recoveryCheckForRun(List<Map<String, dynamic>> checks, String? runId) {
  if (runId == null || runId.isEmpty) return null;
  Map<String, dynamic>? best;
  DateTime? bestAt;
  for (final c in checks) {
    if (c['playbook_run_id']?.toString() != runId) continue;
    final at = parseTime(c['checked_at']);
    if (best == null || (at != null && (bestAt == null || at.isAfter(bestAt)))) {
      best = c;
      bestAt = at;
    }
  }
  return best;
}

/// healthy | unhealthy | failed are final; anything else means 07 is still working.
bool isFinalRecoveryStatus(String? status) =>
    status == 'healthy' || status == 'unhealthy' || status == 'failed';

List<Map<String, dynamic>> recoveryAttempts(Map<String, dynamic>? check) {
  final details = check?['details'];
  final list = details is Map ? details['checks'] : null;
  if (list is! List) return const [];
  return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

/// 0.174 -> "17.4%", 0.05 -> "5%", 0 -> "0%"
String _percent(num v) {
  final text = (v * 100).toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}%';
}

/// "up 1 ✓" / "error rate 17.4% (limit 5%) ✗" / "error rate: no_data"
String describeResult(Map result) {
  final name = result['name']?.toString() ?? 'check';
  final label = name == 'error_rate' ? 'error rate' : name;
  if (result['ok'] != true || result['value'] is! num) {
    return '$label: ${result['error'] ?? 'not measured'}';
  }
  final value = result['value'] as num;
  final threshold = result['threshold'];
  final mark = result['healthy'] == true ? '✓' : '✗';
  if (name == 'error_rate') {
    final limit = threshold is num ? ' (limit ${_percent(threshold)})' : '';
    return '$label ${_percent(value)}$limit $mark';
  }
  return '$label ${value is double && value != value.roundToDouble() ? value.toStringAsFixed(2) : value.round()} $mark';
}

/// "Attempt 2 · 14:22:48 · up 1 ✓ · error rate 0% (limit 5%) ✓"
String describeAttempt(Map<String, dynamic> attempt) {
  final results = attempt['results'] is List ? (attempt['results'] as List).whereType<Map>() : const <Map>[];
  final parts = [
    'Attempt ${attempt['attempt'] ?? '?'}',
    if (attempt['at'] != null) localTime(attempt['at']),
    ...results.map(describeResult),
  ];
  return parts.join(' · ');
}

/// Highest error rate measured across the given recovery checks, or null.
num? peakErrorRate(Iterable<Map<String, dynamic>> checks) {
  num? peak;
  for (final c in checks) {
    for (final a in recoveryAttempts(c)) {
      final results = a['results'] is List ? (a['results'] as List).whereType<Map>() : const <Map>[];
      for (final r in results) {
        if (r['name'] == 'error_rate' && r['ok'] == true && r['value'] is num) {
          final v = r['value'] as num;
          if (peak == null || v > peak) peak = v;
        }
      }
    }
  }
  return peak;
}

String formatErrorRate(num v) => _percent(v);

// ISO timestamps with a UTC "Z" or an explicit offset: 2026-11-21T08:42:36.234Z,
// 2026-11-21T08:39:48.08704+00:00, 2026-11-21 08:39:48+00.
final _isoTime = RegExp(r'\b\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}(?::?\d{2})?)(?![\w:])');
// A UTC time without a date: 08:42:36.234Z, 08:42Z.
final _bareUtcTime = RegExp(r'\b(\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?Z\b');
// "error_rate" / "error rate" / "5xx rate", then up to 60 characters of the same clause.
final _errorRateLabel = RegExp(r'\b(?:error[ _-]?rate|5xx[ _-]?rate)\b', caseSensitive: false);
// A ratio such as 0.502868068833652, .05 or 1.0 that is not already a percentage.
final _ratio = RegExp(r'(?<![\d.])(?:0?\.\d+|1\.0+)(?![\d.]|\s*%)');

/// Text written by the AI or the automation, made readable: UTC times become
/// local times ("14:12:36", with the date when it is not [day]) and error-rate
/// ratios become percentages ("50.3%"). Other text is unchanged.
String readableText(String? text, {DateTime? day}) {
  if (text == null || text.isEmpty) return text ?? '';
  final ref = day?.toLocal();
  var out = text.replaceAllMapped(_isoTime, (m) {
    final t = parseTime(m[0]!.replaceFirst(' ', 'T'));
    if (t == null) return m[0]!;
    return ref != null && sameLocalDay(t, ref) ? localTime(t) : localDateTime(t);
  });
  if (ref != null) {
    final utcDay = ref.toUtc();
    out = out.replaceAllMapped(_bareUtcTime, (m) {
      final t = DateTime.utc(utcDay.year, utcDay.month, utcDay.day, int.parse(m[1]!), int.parse(m[2]!),
          m[3] == null ? 0 : int.parse(m[3]!));
      return m[3] == null ? localTime(t).substring(0, 5) : localTime(t);
    });
  }
  final buf = StringBuffer();
  var pos = 0;
  for (final label in _errorRateLabel.allMatches(out)) {
    if (label.start < pos) continue;
    // The clause after the label ends at ';', a new sentence or 60 characters.
    var end = (label.end + 60).clamp(0, out.length);
    final stop = RegExp(r';|\.\s|\n').firstMatch(out.substring(label.end, end));
    if (stop != null) end = label.end + stop.start;
    buf.write(out.substring(pos, label.end));
    buf.write(out.substring(label.end, end).replaceAllMapped(_ratio, (m) => _percent(double.parse(m[0]!))));
    pos = end;
  }
  buf.write(out.substring(pos));
  return buf.toString();
}

/// Error rate of the last attempt in one recovery check, or null.
num? lastErrorRate(Map<String, dynamic> check) {
  num? last;
  for (final a in recoveryAttempts(check)) {
    final results = a['results'] is List ? (a['results'] as List).whereType<Map>() : const <Map>[];
    for (final r in results) {
      if (r['name'] == 'error_rate' && r['ok'] == true && r['value'] is num) last = r['value'] as num;
    }
  }
  return last;
}

/// One line per remediation, oldest first, e.g.
/// "Scale sample-app: peak 50.4%, not recovered → Roll back sample-app: 0%, recovered".
/// [runNames] maps playbook_run_id to the playbook name.
String? remediationOutcomes(List<Map<String, dynamic>> checks, Map<String, String> runNames) {
  final sorted = [...checks]
    ..sort((a, b) => (parseTime(a['checked_at']) ?? DateTime(0)).compareTo(parseTime(b['checked_at']) ?? DateTime(0)));
  final parts = <String>[];
  for (final c in sorted) {
    final name = runNames[c['playbook_run_id']?.toString()] ?? 'Remediation';
    switch (c['status']) {
      case 'healthy':
        final last = lastErrorRate(c);
        parts.add('$name: ${last != null ? '${_percent(last)}, ' : ''}recovered');
        break;
      case 'unhealthy':
        final peak = peakErrorRate([c]);
        parts.add('$name: ${peak != null ? 'peak ${_percent(peak)}, ' : ''}not recovered');
        break;
      case 'failed':
        parts.add('$name: could not verify');
        break;
    }
  }
  return parts.isEmpty ? null : parts.join(' → ');
}
