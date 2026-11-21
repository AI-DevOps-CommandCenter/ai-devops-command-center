import 'package:flutter/material.dart';
import '../models/incident_model.dart';
import '../models/service_metrics_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';
import 's05_incident_details_screen.dart';
import 's12_service_details_screen.dart';
import 's16_remediation_playbooks_screen.dart';

/// S30 – search across incidents, services and playbooks. The data is loaded
/// once from the backend and filtered on the device.
class S30SearchScreen extends StatefulWidget {
  const S30SearchScreen({super.key});

  @override
  State<S30SearchScreen> createState() => _S30SearchScreenState();
}

class _S30SearchScreenState extends State<S30SearchScreen> {
  final _controller = TextEditingController();
  List<IncidentModel> _incidents = [];
  List<ServiceHealth> _services = [];
  List<Map<String, dynamic>> _playbooks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ApiService();
    try {
      _incidents = await api.fetchIncidents();
    } catch (e) {
      _error = e is ApiException ? e.message : 'Could not load incidents.';
    }
    // Services and playbooks are optional extras for the search.
    try {
      _services = await api.fetchServiceHealth();
    } catch (_) {
      _services = [];
    }
    try {
      _playbooks = await api.fetchPlaybooks();
    } catch (_) {
      _playbooks = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _match(String q, Iterable<String?> fields) => fields.any((f) => f != null && f.toLowerCase().contains(q));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final q = _controller.text.trim().toLowerCase();
    final incidents = q.isEmpty ? <IncidentModel>[] : _incidents.where((i) => _match(q, [i.title, i.serviceName, i.id, i.summary])).toList();
    final services = q.isEmpty ? <ServiceHealth>[] : _services.where((s) => _match(q, [s.service])).toList();
    final playbooks = q.isEmpty
        ? <Map<String, dynamic>>[]
        : _playbooks.where((p) => _match(q, [p['name']?.toString(), p['description']?.toString(), p['action_type']?.toString()])).toList();
    final total = incidents.length + services.length + playbooks.length;

    Widget row(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: FlowCard(
              child: Row(children: [
                Icon(icon, color: colors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                    Text(sub, style: TextStyle(fontSize: 12, color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Icon(Icons.chevron_right, color: colors.muted),
              ]),
            ),
          ),
        );

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: colors.muted)),
        );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const FlowHeader(title: 'Search', subtitle: 'Incidents, services and playbooks'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_controller.clear),
                        ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const FlowMessage(icon: Icons.search, message: 'Loading…', busy: true)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (_error != null) Text(_error!, style: TextStyle(fontSize: 12, color: colors.critical)),
                        if (q.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text('Type to search ${_incidents.length} incidents, ${_services.length} services and ${_playbooks.length} playbooks.',
                                  textAlign: TextAlign.center, style: TextStyle(color: colors.muted)),
                            ),
                          )
                        else if (total == 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(child: Text('No results for "${_controller.text.trim()}".', style: TextStyle(color: colors.muted))),
                          ),
                        if (incidents.isNotEmpty) label('INCIDENTS'),
                        ...incidents.map((i) => row(
                              Icons.warning_amber_rounded,
                              i.title,
                              '${i.serviceName} · ${i.status.name} · ${i.severity.name}',
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => S05IncidentDetailsScreen(incidentId: i.id),
                                  settings: RouteSettings(arguments: i.id),
                                ),
                              ),
                            )),
                        if (services.isNotEmpty) label('SERVICES'),
                        ...services.map((s) => row(
                              Icons.dns_outlined,
                              s.service,
                              s.status,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => S12ServiceDetailsScreen(service: s.service),
                                  settings: RouteSettings(arguments: s.service),
                                ),
                              ),
                            )),
                        if (playbooks.isNotEmpty) label('PLAYBOOKS'),
                        ...playbooks.map((p) => row(
                              Icons.playlist_play,
                              p['name']?.toString() ?? '—',
                              p['action_type']?.toString() ?? '',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const S16RemediationPlaybooksScreen())),
                            )),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
