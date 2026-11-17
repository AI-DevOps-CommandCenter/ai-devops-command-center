import 'dart:async';

import 'package:flutter/material.dart';
import '../models/incident_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';
import 's07_root_cause_screen.dart';

/// S06 – live progress of the n8n AI investigation for one incident.
/// Polls GET /api/investigations?incident_id=… until the investigation is
/// completed or failed, then offers the root-cause screen (S07).
class S06AiInvestigationProgressScreen extends StatefulWidget {
  final String? incidentId;

  const S06AiInvestigationProgressScreen({super.key, this.incidentId});

  @override
  State<S06AiInvestigationProgressScreen> createState() => _S06AiInvestigationProgressScreenState();
}

class _S06AiInvestigationProgressScreenState extends State<S06AiInvestigationProgressScreen> {
  String? _incidentId;
  IncidentModel? _incident;
  Map<String, dynamic>? _investigation;
  String? _error;
  bool _loading = true;
  Timer? _poll;
  int _polls = 0;
  static const _maxPolls = 60; // 5 minutes at 5 s

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

  String get _status => _investigation?['status']?.toString() ?? 'pending';
  bool get _finished => _status == 'completed' || _status == 'failed';

  Future<void> _load() async {
    final id = _incidentId;
    if (id == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Open this screen from an incident.';
      });
      return;
    }
    try {
      final api = ApiService();
      final incident = _incident ?? await api.fetchIncidentById(id);
      final list = await api.fetchInvestigations(id);
      list.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      if (!mounted) return;
      setState(() {
        _incident = incident;
        _investigation = list.isEmpty ? null : list.first;
        _loading = false;
        _error = null;
      });
      _schedule();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load the investigation.';
      });
    }
  }

  void _schedule() {
    _poll?.cancel();
    if (_finished || _polls >= _maxPolls) return;
    _polls++;
    _poll = Timer(const Duration(seconds: 5), _load);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = _incident == null
        ? 'Loading…'
        : 'INC-${_incident!.id.substring(0, _incident!.id.length < 8 ? _incident!.id.length : 8).toUpperCase()} · ${_incident!.serviceName}';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'AI investigation', subtitle: subtitle),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.hourglass_empty, message: 'Loading investigation…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);

    final status = _status;
    final completed = status == 'completed';
    final failed = status == 'failed';
    // The four n8n stages; the investigation row only records the overall status,
    // so while it runs the first three are shown as in progress together.
    final steps = <(String, String, String)>[
      ('Read logs', 'Recent error lines for this service', 'Source: Loki'),
      ('Check metrics', 'Error rate, latency and resource use around the alert', 'Source: Prometheus'),
      ('Review deployments', 'Commits and deployments in the last 24 h', 'Source: GitHub'),
      ('Correlate and explain', 'Combine the three results into one probable cause', 'Source: Groq via n8n'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowStepper(activeStage: completed ? 2 : 1),
          const SizedBox(height: 14),
          FlowCard(
            child: Row(
              children: [
                if (!completed && !failed)
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: colors.accent))
                else
                  Icon(completed ? Icons.check_circle : Icons.error, color: completed ? colors.success : colors.critical),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    completed
                        ? 'Investigation complete'
                        : failed
                            ? 'Investigation failed – check the n8n error log'
                            : _investigation == null
                                ? 'Waiting for n8n to start the investigation'
                                : 'Investigating…',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) {
            final (title, desc, source) = steps[i];
            final done = completed;
            final running = !completed && !failed && _investigation != null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FlowCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      done ? Icons.check_circle_outline : running ? Icons.timelapse : Icons.radio_button_unchecked,
                      size: 20,
                      color: done ? colors.success : running ? colors.accent : colors.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                          const SizedBox(height: 3),
                          Text(desc, style: TextStyle(fontSize: 13, color: colors.muted)),
                          const SizedBox(height: 3),
                          Text(source, style: TextStyle(fontSize: 11, color: colors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            'The AI only reads data and suggests. It can recommend a reviewed playbook, but it cannot run anything on its own.',
            style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: completed
                  ? () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => S07RootCauseScreen(incidentId: _incidentId),
                          settings: RouteSettings(arguments: _incidentId),
                        ),
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View probable cause', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
