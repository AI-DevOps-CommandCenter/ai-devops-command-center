import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';

/// S39 – audit trail written by database triggers (GET /api/audit-logs).
class S39AuditLogScreen extends StatefulWidget {
  const S39AuditLogScreen({super.key});

  @override
  State<S39AuditLogScreen> createState() => _S39AuditLogScreenState();
}

class _S39AuditLogScreenState extends State<S39AuditLogScreen> {
  static const _filters = {
    '': 'All',
    'incident': 'Incidents',
    'approval_request': 'Approvals',
    'playbook_run': 'Runs',
    'postmortem': 'Postmortems',
  };

  String _filter = '';
  List<Map<String, dynamic>> _logs = [];
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
      final logs = await ApiService().fetchAuditLogs(entityType: _filter, limit: 100);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException && e.statusCode == 403
            ? 'Only operators and admins can read the audit log.'
            : e is ApiException
                ? e.message
                : 'Could not load the audit log.';
      });
    }
  }

  String _label(String action) {
    final words = action.toLowerCase().split('_');
    return words.isEmpty ? action : '${words.first[0].toUpperCase()}${words.first.substring(1)} ${words.skip(1).join(' ')}'.trim();
  }

  String _time(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'Audit log', subtitle: _loading ? 'Loading…' : '${_logs.length} entries'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filters.entries
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.value),
                            selected: _filter == f.key,
                            onSelected: (_) {
                              _filter = f.key;
                              _load();
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.fact_check_outlined, message: 'Loading audit log…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);
    if (_logs.isEmpty) return FlowMessage(icon: Icons.fact_check_outlined, message: 'No entries.', onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _logs.length,
        itemBuilder: (_, i) {
          final l = _logs[i];
          final details = l['details'] is Map ? Map<String, dynamic>.from(l['details']) : <String, dynamic>{};
          final role = details['actor_role']?.toString();
          final extra = [
            if (details['old_status'] != null && details['status'] != null) '${details['old_status']} → ${details['status']}',
            if (details['old_status'] == null && details['status'] != null) 'status ${details['status']}',
          ].join(' · ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(_label(l['action']?.toString() ?? ''),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                    ),
                    Text(_time(l['created_at']?.toString()), style: TextStyle(fontSize: 11, color: colors.muted)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '${l['entity_type']} ${l['entity_id']?.toString().substring(0, 8) ?? ''}',
                      if (role != null) 'by $role',
                      if (extra.isNotEmpty) extra,
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
