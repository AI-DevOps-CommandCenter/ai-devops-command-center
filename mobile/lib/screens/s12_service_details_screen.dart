import 'package:flutter/material.dart';
import '../models/incident_model.dart';
import '../models/service_metrics_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/metric_widgets.dart';
import 's05_incident_details_screen.dart';
import 's10_metrics_screen.dart';

/// S12 – one service: health, last-hour metrics and its open incidents.
class S12ServiceDetailsScreen extends StatefulWidget {
  final String? service;

  const S12ServiceDetailsScreen({super.key, this.service});

  @override
  State<S12ServiceDetailsScreen> createState() => _S12ServiceDetailsScreenState();
}

class _S12ServiceDetailsScreenState extends State<S12ServiceDetailsScreen> {
  String? _service;
  ServiceHealth? _health;
  ServiceMetrics? _metrics;
  List<IncidentModel> _incidents = [];
  bool _loading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      _service = (args is String && args.isNotEmpty) ? args : (widget.service ?? 'sample-app');
      _load();
    }
  }

  Future<void> _load() async {
    final service = _service!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.fetchServiceHealth(),
        api.fetchServiceMetrics(service),
        api.fetchIncidents(serviceName: service),
      ]);
      if (!mounted) return;
      final health = (results[0] as List<ServiceHealth>).where((h) => h.service == service);
      setState(() {
        _health = health.isEmpty ? null : health.first;
        _metrics = results[1] as ServiceMetrics;
        _incidents = (results[2] as List<IncidentModel>).where((i) => i.status != IncidentStatus.resolved).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load the service.';
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
            FlowHeader(title: _service ?? 'Service', subtitle: 'Service details · Prometheus'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'monitor'),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.dns_outlined, message: 'Loading service…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);
    final h = _health;
    final (Color tone, String label) = switch (h?.status) {
      'healthy' => (colors.ok, 'Healthy'),
      'warning' => (colors.warning, 'High error rate'),
      _ => (colors.critical, 'Down'),
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FlowCard(
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text))),
              Text(MetricFormat.perSecond(_metrics?.requestRate.current),
                  style: TextStyle(fontSize: 13, color: colors.muted)),
            ]),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LAST HOUR',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: colors.muted)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => S10MetricsScreen(service: _service), settings: RouteSettings(arguments: _service)),
                ),
                child: const Text('All metrics'),
              ),
            ],
          ),
          if (_metrics != null) ServiceMetricsGrid(metrics: _metrics!),
          const SizedBox(height: 16),
          Text('OPEN INCIDENTS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: colors.muted)),
          const SizedBox(height: 8),
          if (_incidents.isEmpty)
            FlowCard(child: Text('No open incidents for this service.', style: TextStyle(fontSize: 13, color: colors.muted)))
          else
            ..._incidents.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => S05IncidentDetailsScreen(incidentId: i.id),
                        settings: RouteSettings(arguments: i.id),
                      ),
                    ),
                    child: FlowCard(
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            color: i.severity == IncidentSeverity.critical ? colors.critical : colors.warning),
                        const SizedBox(width: 10),
                        Expanded(child: Text(i.title, style: TextStyle(fontSize: 14, color: colors.text))),
                        Icon(Icons.chevron_right, color: colors.muted),
                      ]),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
