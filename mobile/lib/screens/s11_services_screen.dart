import 'package:flutter/material.dart';
import '../models/service_metrics_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/metric_widgets.dart';
import 's12_service_details_screen.dart';

/// S11 – every service Prometheus scrapes, with its health (GET /api/metrics/services).
class S11ServicesScreen extends StatefulWidget {
  const S11ServicesScreen({super.key});

  @override
  State<S11ServicesScreen> createState() => _S11ServicesScreenState();
}

class _S11ServicesScreenState extends State<S11ServicesScreen> {
  List<ServiceHealth> _services = [];
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
      final services = await ApiService().fetchServiceHealth();
      if (!mounted) return;
      setState(() {
        _services = services;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load services.';
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
            FlowHeader(title: 'Services', subtitle: _loading ? 'Loading…' : '${_services.length} monitored by Prometheus'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'monitor'),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.dns_outlined, message: 'Loading services…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);
    if (_services.isEmpty) return FlowMessage(icon: Icons.dns_outlined, message: 'Prometheus reports no services.', onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FlowCard(child: ServiceHealthBar(services: _services)),
          const SizedBox(height: 14),
          ..._services.map((s) {
            final (Color tone, String label) = switch (s.status) {
              'healthy' => (colors.ok, 'Healthy'),
              'warning' => (colors.warning, 'High error rate'),
              _ => (colors.critical, 'Down'),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => S12ServiceDetailsScreen(service: s.service),
                    settings: RouteSettings(arguments: s.service),
                  ),
                ),
                child: FlowCard(
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.service, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                            const SizedBox(height: 2),
                            Text(
                              s.errorRate == null ? label : '$label · errors ${MetricFormat.percent(s.errorRate)}',
                              style: TextStyle(fontSize: 13, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.muted),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
