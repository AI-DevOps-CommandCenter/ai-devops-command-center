import 'package:flutter/material.dart';
import '../models/service_metrics_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/metric_widgets.dart';

/// S10 – live Prometheus metrics for one service (GET /api/metrics/services/:service).
/// The service comes from the constructor or the route argument; otherwise the
/// first service Prometheus reports with HTTP traffic is used.
class S10MetricsScreen extends StatefulWidget {
  final String? service;

  const S10MetricsScreen({super.key, this.service});

  @override
  State<S10MetricsScreen> createState() => _S10MetricsScreenState();
}

class _S10MetricsScreenState extends State<S10MetricsScreen> {
  static const _windows = [15, 60, 360];

  String? _service;
  int _window = 60;
  List<ServiceHealth> _services = [];
  ServiceMetrics? _metrics;
  bool _loading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      _service = (args is String && args.isNotEmpty) ? args : widget.service;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final services = await api.fetchServiceHealth();
      final service = _service ??
          (services.any((s) => s.service == 'sample-app')
              ? 'sample-app'
              : services.isNotEmpty
                  ? services.first.service
                  : null);
      if (service == null) throw ApiException('Prometheus reports no services.');
      final metrics = await api.fetchServiceMetrics(service, windowMinutes: _window);
      if (!mounted) return;
      setState(() {
        _services = services;
        _service = service;
        _metrics = metrics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load metrics.';
      });
    }
  }

  String _windowLabel(int m) => m < 60 ? '$m min' : '${m ~/ 60} h';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'Metrics', subtitle: '${_service ?? '…'} · Prometheus · last ${_windowLabel(_window)}'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'monitor'),
    );
  }

  Widget _chips(AppColorScheme colors, List<String> items, String selected, ValueChanged<String> onTap) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            final on = item == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item),
                selected: on,
                onSelected: (_) => onTap(item),
                selectedColor: colors.accentSoft,
                labelStyle: TextStyle(fontSize: 12, color: on ? colors.accent : colors.muted, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
        ),
      );

  Widget _body(AppColorScheme colors) {
    if (_loading && _metrics == null) return const FlowMessage(icon: Icons.show_chart, message: 'Loading metrics…', busy: true);
    if (_error != null && _metrics == null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);
    final m = _metrics!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (_services.length > 1) ...[
            _chips(colors, _services.map((s) => s.service).toList(), m.service, (s) {
              _service = s;
              _load();
            }),
            const SizedBox(height: 4),
          ],
          _chips(colors, _windows.map(_windowLabel).toList(), _windowLabel(_window), (label) {
            _window = _windows.firstWhere((w) => _windowLabel(w) == label);
            _load();
          }),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(fontSize: 12, color: colors.critical)),
            ),
          ServiceMetricsGrid(metrics: m, chartHeight: 60),
          const SizedBox(height: 8),
          MetricCard(
            title: 'Request rate',
            value: MetricFormat.perSecond(m.requestRate.current),
            sub: 'All HTTP requests',
            values: m.requestRate.values,
            color: colors.accent,
            chartHeight: 60,
          ),
          const SizedBox(height: 12),
          Text(
            'Values come straight from Prometheus. The same queries are used by the n8n investigation (workflow 03) and recovery check (workflow 07).',
            style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
