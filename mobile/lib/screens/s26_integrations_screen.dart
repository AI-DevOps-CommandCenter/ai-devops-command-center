import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';

/// S26 – live status of the services the command center depends on, checked
/// through the backend, plus integration records stored by admins
/// (GET /api/admin/integrations).
class S26IntegrationsScreen extends StatefulWidget {
  const S26IntegrationsScreen({super.key});

  @override
  State<S26IntegrationsScreen> createState() => _S26IntegrationsScreenState();
}

class _Check {
  final String name;
  final String purpose;
  final IconData icon;
  bool? ok;
  String detail = 'Checking…';
  _Check(this.name, this.purpose, this.icon);
}

class _S26IntegrationsScreenState extends State<S26IntegrationsScreen> {
  final _checks = [
    _Check('Supabase', 'Sign-in, database and audit trail', Icons.storage_outlined),
    _Check('Prometheus', 'Metrics, alerts and recovery checks', Icons.show_chart),
    _Check('GitHub', 'Commits, pull requests and pipelines', Icons.code),
  ];
  List<Map<String, dynamic>> _records = [];
  String? _recordsError;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (final c in _checks) {
      c.ok = null;
      c.detail = 'Checking…';
    }
    setState(() {});
    final api = ApiService();

    final supa = _checks[0];
    final user = AuthService().currentUser;
    supa.ok = user != null;
    supa.detail = user == null ? 'Not signed in' : 'Signed in as ${user.email} (${user.roleLabel})';

    await Future.wait([
      () async {
        final c = _checks[1];
        try {
          final services = await api.fetchServiceHealth();
          final up = services.where((s) => s.up).length;
          c.ok = true;
          c.detail = '$up of ${services.length} scraped services up';
        } catch (e) {
          c.ok = false;
          c.detail = e is ApiException ? e.message : 'Not reachable';
        }
      }(),
      () async {
        final c = _checks[2];
        try {
          final repos = await api.fetchRepositories();
          c.ok = true;
          c.detail = repos.isEmpty ? 'Connected, no repositories' : repos.map((r) => r.fullName).join(', ');
        } catch (e) {
          c.ok = false;
          c.detail = e is ApiException && (e.statusCode == 503 || e.statusCode == 502)
              ? 'Not connected – set GITHUB_TOKEN in backend/.env'
              : e is ApiException
                  ? e.message
                  : 'Not reachable';
        }
      }(),
      () async {
        try {
          _records = await api.fetchIntegrations();
          _recordsError = null;
        } catch (e) {
          _records = [];
          _recordsError = e is ApiException ? e.message : 'Could not load integration records.';
        }
      }(),
    ]);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const FlowHeader(title: 'Integrations', subtitle: 'Checked live through the backend'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _run,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    ..._checks.map((c) {
                      final tone = c.ok == null ? colors.muted : c.ok! ? colors.success : colors.critical;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FlowCard(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(c.icon, color: colors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                                Text(c.purpose, style: TextStyle(fontSize: 12, color: colors.muted)),
                                const SizedBox(height: 6),
                                Text(c.detail, style: TextStyle(fontSize: 13, color: colors.text)),
                              ]),
                            ),
                            Icon(
                              c.ok == null ? Icons.more_horiz : c.ok! ? Icons.check_circle : Icons.error_outline,
                              color: tone,
                            ),
                          ]),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    Text('n8n automation is called by the backend over signed webhooks; its status is in the health check script (scripts/check-project.mjs).',
                        style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4)),
                    const SizedBox(height: 16),
                    Text('STORED INTEGRATIONS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: colors.muted)),
                    const SizedBox(height: 8),
                    if (_recordsError != null)
                      FlowCard(child: Text(_recordsError!, style: TextStyle(fontSize: 13, color: colors.muted)))
                    else if (_records.isEmpty)
                      FlowCard(child: Text('None stored yet.', style: TextStyle(fontSize: 13, color: colors.muted)))
                    else
                      ..._records.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: FlowCard(
                              child: Row(children: [
                                Expanded(
                                  child: Text('${r['name'] ?? r['type'] ?? 'Integration'}',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                                ),
                                Text(r['enabled'] == false ? 'disabled' : 'enabled',
                                    style: TextStyle(fontSize: 12, color: colors.muted)),
                              ]),
                            ),
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
