import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../models/incident_model.dart';
import '../widgets/flow_widgets.dart';
import '../utils/run_format.dart';

/// S21 Postmortem report.
/// Shows the postmortem draft written by n8n workflow 08 (Groq, validated
/// against postmortem-output.schema.json) via GET /api/postmortems?incident_id=.
/// Polls every 5 s until it exists. It is an AI draft for humans to review.
class S21PostmortemReportScreen extends StatefulWidget {
  final String? incidentId;

  const S21PostmortemReportScreen({super.key, this.incidentId});

  @override
  State<S21PostmortemReportScreen> createState() => _S21PostmortemReportScreenState();
}

class _S21PostmortemReportScreenState extends State<S21PostmortemReportScreen> {
  String? _incidentId;
  IncidentModel? _incident;
  Map<String, dynamic>? _postmortem;
  List<Map<String, dynamic>> _checks = const [];
  Map<String, String> _runNames = const {};
  String? _errorMessage;
  bool _isLoading = true;
  Timer? _poll;
  int _polls = 0;

  static const _maxPolls = 36; // 3 minutes

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_incidentId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _incidentId = (args is String && args.isNotEmpty) ? args : widget.incidentId;
      _load();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _incidentId;
    if (id == null || id.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Open this screen from an incident.';
      });
      return;
    }
    try {
      final api = ApiService();
      final incident = _incident ?? await api.fetchIncidentById(id);
      final postmortem = await api.fetchLatestPostmortem(id);
      var checks = _checks;
      var runNames = _runNames;
      try {
        checks = await api.fetchRecoveryChecks(id);
        final runs = await api.fetchPlaybookRuns(incidentId: id);
        runNames = {
          for (final r in runs)
            if (r.incidentId == id) r.id: r.playbookName ?? r.actionType.displayName,
        };
      } catch (_) {
        // Measured impact is optional; the report still shows.
      }
      if (!mounted) return;
      setState(() {
        _incident = incident;
        _postmortem = postmortem;
        _checks = checks;
        _runNames = runNames;
        _errorMessage = null;
        _isLoading = false;
      });
      if (postmortem == null && _polls < _maxPolls) {
        _polls++;
        _poll?.cancel();
        _poll = Timer(const Duration(seconds: 5), _load);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  List<String> _strings(dynamic value) =>
      value is List ? value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList() : const [];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final created = _postmortem?['updated_at'] ?? _postmortem?['created_at'];
    final subtitle = _incident == null
        ? 'Loading…'
        : '${_incident!.title}${created != null ? ' · generated ${_shortTime(created.toString())}' : ''}';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'Postmortem', subtitle: subtitle),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  String _shortTime(String iso) => localDateTime(iso);

  /// Timeline rows as local "13:11:52  event". The date is shown once in the
  /// section label, and again on the first row of any later day.
  ({String? date, List<String> rows}) _timeline(dynamic raw) {
    final entries = (raw is List ? raw : const []).whereType<Map>().toList();
    String? firstDate;
    DateTime? lastDay;
    final rows = <String>[];
    for (final e in entries) {
      final t = parseTime(e['time']);
      final event = e['event']?.toString() ?? '';
      if (t == null) {
        rows.add('${e['time'] ?? ''}  $event'.trim());
        continue;
      }
      firstDate ??= localDate(t);
      final newDay = lastDay != null && !sameLocalDay(lastDay, t);
      lastDay = t;
      rows.add('${newDay ? '${localDate(t)}, ' : ''}${localTime(t)}  $event');
    }
    return (date: firstDate, rows: rows);
  }

  /// Facts measured by the recovery checks (workflow 07): time from detection
  /// to the first healthy check, and the outcome of each remediation.
  List<String> _measuredImpact() {
    final incident = _incident;
    if (incident == null || _checks.isEmpty) return const [];
    final facts = <String>[];
    DateTime? recoveredAt;
    for (final c in _checks) {
      if (c['status'] != 'healthy') continue;
      final at = parseTime(c['checked_at']);
      if (at != null && (recoveredAt == null || at.isBefore(recoveredAt))) recoveredAt = at;
    }
    if (recoveredAt != null) {
      facts.add('Detected ${localTime(incident.detectedAt)}, recovered ${localTime(recoveredAt)} '
          '(${formatDuration(recoveredAt.difference(incident.detectedAt.toLocal()))})');
    }
    // Per remediation, so a failed attempt's peak is not read as the result.
    final outcomes = remediationOutcomes(_checks, _runNames);
    if (outcomes != null) facts.add(outcomes);
    return facts;
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;
    if (_isLoading) return const FlowMessage(icon: Icons.hourglass_top, message: 'Loading…', busy: true);
    if (_errorMessage != null) {
      return FlowMessage(icon: Icons.error_outline, message: _errorMessage!, onRetry: () {
        setState(() => _isLoading = true);
        _load();
      });
    }
    final pm = _postmortem;
    if (pm == null) {
      return FlowMessage(
        icon: Icons.description_outlined,
        message: _polls < _maxPolls
            ? 'The AI is writing the postmortem draft…\nThis page refreshes every 5 seconds.'
            : 'No postmortem yet for this incident.',
        busy: _polls < _maxPolls,
        onRetry: _polls < _maxPolls ? null : () {
          _polls = 0;
          _load();
        },
      );
    }

    final report = pm['report'] is Map ? Map<String, dynamic>.from(pm['report']) : <String, dynamic>{};
    final timeline = _timeline(pm['timeline']);
    final measured = _measuredImpact();
    final aiImpact = pm['impact']?.toString();
    final aiImpactUnknown = aiImpact == null || aiImpact.trim().isEmpty || aiImpact.toLowerCase().startsWith('unknown');
    final lessons = _strings(report['lessons_learned']);
    final actions = _strings(pm['action_items']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const FlowStepper(activeStage: 5),
          const SizedBox(height: 14),
          if (report['title'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(report['title'].toString(),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.text)),
            ),
          FlowSection(label: 'Summary', text: pm['summary']?.toString()),
          // AI text plus the measured facts; an "Unknown" AI answer is replaced
          // by the measured facts when there are any.
          FlowSection(
            label: 'Impact',
            text: aiImpactUnknown && measured.isNotEmpty ? null : aiImpact,
            items: measured.isNotEmpty ? measured : null,
          ),
          FlowSection(label: timeline.date == null ? 'Timeline' : 'Timeline · ${timeline.date}', items: timeline.rows),
          FlowSection(label: 'Root cause', text: pm['root_cause']?.toString()),
          if (report['remediation'] != null) FlowSection(label: 'Remediation', text: report['remediation'].toString()),
          if (report['recovery_result'] != null)
            FlowSection(label: 'Recovery result', text: report['recovery_result'].toString()),
          if (_strings(report['evidence']).isNotEmpty) FlowSection(label: 'Evidence', items: _strings(report['evidence'])),
          FlowSection(
            label: 'Lessons learned',
            items: lessons.isNotEmpty ? lessons : null,
            text: lessons.isEmpty ? pm['lessons_learned']?.toString() : null,
          ),
          FlowSection(label: 'Preventive actions', items: actions),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: colors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('AI-generated draft. Review before sharing.',
                    style: TextStyle(fontSize: 12, color: colors.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
