import 'package:flutter/material.dart';
import '../models/incident_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/explain_panel.dart';
import '../widgets/flow_widgets.dart';
import 's07_root_cause_screen.dart';

/// S23 – AI tab (developer assistant):
///  - "Explain a log or error": paste text, POST /api/assistant/explain explains
///    it (meaning, likely cause, what to check next). Explanation only.
///  - the latest AI analysis of each recent incident (root cause, recommended
///    action, confidence, model), from GET /api/incidents/:id/recommendation,
///    produced by n8n workflow 05 with Groq; the app only reads them.
class S23DeveloperAssistantScreen extends StatefulWidget {
  /// Kept for route compatibility (an incident id to show first); optional.
  final String? initialContext;

  const S23DeveloperAssistantScreen({super.key, this.initialContext});

  @override
  State<S23DeveloperAssistantScreen> createState() => _S23DeveloperAssistantScreenState();
}

class _Entry {
  final IncidentModel incident;
  final Map<String, dynamic> analysis;
  _Entry(this.incident, this.analysis);
}

class _S23DeveloperAssistantScreenState extends State<S23DeveloperAssistantScreen> {
  List<_Entry> _entries = [];
  int _withoutAnalysis = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final incidents = (await api.fetchIncidents())..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
      final recent = incidents.take(20).toList();
      final results = await Future.wait(recent.map((i) async {
        try {
          final rec = await api.fetchRecommendation(i.id);
          final a = rec['analysis'];
          return a is Map<String, dynamic> ? _Entry(i, a) : null;
        } catch (_) {
          return null;
        }
      }));
      final entries = results.whereType<_Entry>().toList();
      final first = widget.initialContext;
      if (first != null) {
        entries.sort((a, b) => a.incident.id == first ? -1 : (b.incident.id == first ? 1 : 0));
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _withoutAnalysis = recent.length - entries.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load AI analyses.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'Developer assistant', subtitle: _loading ? 'Loading analyses…' : '${_entries.length} incidents analysed'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'assistant'),
    );
  }

  Widget _body(AppColorScheme colors) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const ExplainPanel(),
          const SizedBox(height: 16),
          Text('Incident analyses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load)
          else if (_entries.isEmpty)
            Text('No AI analysis has been stored yet.', style: TextStyle(fontSize: 12, color: colors.muted))
          else ...[
          Text(
            'Each analysis is written by the n8n investigation (logs, metrics and deployments, explained by Groq). The AI only suggests; a person approves every fix.',
            style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          ..._entries.map((e) {
            final a = e.analysis;
            final conf = (a['confidence'] as num?)?.toDouble();
            final resolved = e.incident.status == IncidentStatus.resolved;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => S07RootCauseScreen(incidentId: e.incident.id),
                    settings: RouteSettings(arguments: e.incident.id),
                  ),
                ),
                child: FlowCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome, size: 16, color: colors.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.incident.title,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(resolved ? 'resolved' : e.incident.status.name,
                            style: TextStyle(fontSize: 11, color: resolved ? colors.success : colors.warning)),
                      ]),
                      const SizedBox(height: 8),
                      Text(a['root_cause']?.toString() ?? '—', style: TextStyle(fontSize: 13, color: colors.text, height: 1.35)),
                      const SizedBox(height: 8),
                      Text(
                        [
                          'recommends ${a['recommended_action'] ?? '—'}',
                          if (conf != null) 'confidence ${(conf * 100).round()}%',
                          if (a['model_name'] != null) '${a['model_name']}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_withoutAnalysis > 0)
            Text('$_withoutAnalysis recent incident(s) have no AI analysis yet.', style: TextStyle(fontSize: 12, color: colors.muted)),
          ],
        ],
      ),
    );
  }
}
