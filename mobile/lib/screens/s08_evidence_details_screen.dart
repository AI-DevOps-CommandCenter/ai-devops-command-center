import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';
import '../utils/run_format.dart';

/// S08 – the evidence behind the latest AI analysis of an incident
/// (GET /api/incidents/:id/recommendation → analysis).
class S08EvidenceDetailsScreen extends StatefulWidget {
  final String? incidentId;

  const S08EvidenceDetailsScreen({super.key, this.incidentId});

  @override
  State<S08EvidenceDetailsScreen> createState() => _S08EvidenceDetailsScreenState();
}

class _S08EvidenceDetailsScreenState extends State<S08EvidenceDetailsScreen> {
  String? _incidentId;
  Map<String, dynamic>? _analysis;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_incidentId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _incidentId = (args is String && args.isNotEmpty) ? args : widget.incidentId;
      _load();
    }
  }

  Future<void> _load() async {
    final id = _incidentId;
    if (id == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Open this screen from an incident.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rec = await ApiService().fetchRecommendation(id);
      if (!mounted) return;
      setState(() {
        _analysis = rec['analysis'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load the evidence.';
      });
    }
  }

  /// Groups evidence lines by the data source they mention.
  String _sourceOf(String line) {
    final l = line.toLowerCase();
    if (l.contains('log') || l.contains('traceback') || l.contains('loki')) return 'Logs';
    if (l.contains('metric') || l.contains('prometheus') || l.contains('cpu') || l.contains('latency') || l.contains('rate')) {
      return 'Metrics';
    }
    if (l.contains('commit') || l.contains('deploy') || l.contains('github')) return 'Deployments';
    return 'Other';
  }

  IconData _iconOf(String source) => switch (source) {
        'Logs' => Icons.receipt_long_outlined,
        'Metrics' => Icons.show_chart,
        'Deployments' => Icons.rocket_launch_outlined,
        _ => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const FlowHeader(title: 'Evidence', subtitle: 'What the AI based its conclusion on'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.hourglass_empty, message: 'Loading evidence…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);
    final a = _analysis;
    if (a == null) {
      return FlowMessage(icon: Icons.search_off, message: 'No AI analysis has been stored for this incident yet.', onRetry: _load);
    }

    // Local times and error rates as percentages (readableText).
    final day = parseTime(a['created_at']);
    final evidence = (a['evidence'] is List ? a['evidence'] as List : const [])
        .map((e) => e is Map ? (e['description'] ?? e['title'] ?? e.toString()).toString() : e.toString())
        .map((line) => readableText(line, day: day))
        .toList();
    final groups = <String, List<String>>{};
    for (final line in evidence) {
      groups.putIfAbsent(_sourceOf(line), () => []).add(line);
    }
    final confidence = (a['confidence'] as num?)?.toDouble();
    final created = DateTime.tryParse(a['created_at']?.toString() ?? '')?.toLocal();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FlowSection(label: 'Probable cause', text: a['root_cause'] == null ? null : readableText(a['root_cause'].toString(), day: day)),
          FlowSection(label: 'Summary', text: a['summary'] == null ? null : readableText(a['summary'].toString(), day: day)),
          if (groups.isEmpty) const FlowSection(label: 'Evidence', text: 'The analysis did not list any evidence.'),
          ...groups.entries.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: FlowCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(_iconOf(g.key), size: 18, color: colors.accent),
                        const SizedBox(width: 8),
                        Text(g.key.toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: colors.muted)),
                      ]),
                      const SizedBox(height: 8),
                      ...g.value.map((line) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(line, style: TextStyle(fontSize: 13, height: 1.4, color: colors.text)),
                          )),
                    ],
                  ),
                ),
              )),
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(colors, 'Confidence', confidence == null ? '—' : '${(confidence * 100).round()} %'),
                _row(colors, 'Severity', a['severity']?.toString() ?? '—'),
                _row(colors, 'Recommended action', a['recommended_action']?.toString() ?? '—'),
                _row(colors, 'Model', a['model_name']?.toString() ?? '—'),
                _row(colors, 'Analysed at',
                    created == null ? '—' : '${created.year}-${_pad2(created.month)}-${_pad2(created.day)} ${_pad2(created.hour)}:${_pad2(created.minute)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pad2(int v) => v.toString().padLeft(2, '0');

  Widget _row(AppColorScheme colors, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(fontSize: 13, color: colors.muted))),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.text))),
        ]),
      );
}
