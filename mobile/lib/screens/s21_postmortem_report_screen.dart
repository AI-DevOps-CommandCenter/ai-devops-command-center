import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../models/incident_model.dart';
import '../widgets/flow_widgets.dart';

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
      if (!mounted) return;
      setState(() {
        _incident = incident;
        _postmortem = postmortem;
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

  String _shortTime(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
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
    final timeline = (pm['timeline'] is List ? pm['timeline'] as List : const [])
        .whereType<Map>()
        .map((e) => '${e['time'] ?? ''}  ${e['event'] ?? ''}'.trim())
        .toList();
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
          FlowSection(label: 'Impact', text: pm['impact']?.toString()),
          FlowSection(label: 'Timeline', items: timeline),
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
