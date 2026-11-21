import 'package:flutter/material.dart';
import '../models/service_metrics_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/flow_widgets.dart';

/// S09 – recent log lines of a service from Loki (GET /api/logs/services/:service).
/// "Errors" uses the same filter as the n8n log analysis (workflow 02).
class S09LogsExplorerScreen extends StatefulWidget {
  final String? service;

  const S09LogsExplorerScreen({super.key, this.service});

  @override
  State<S09LogsExplorerScreen> createState() => _S09LogsExplorerScreenState();
}

class _S09LogsExplorerScreenState extends State<S09LogsExplorerScreen> {
  static const _windows = [15, 60, 360];

  String? _service;
  List<String> _services = [];
  int _minutes = 60;
  bool _errorsOnly = true;
  List<LogLineModel> _lines = [];
  bool _loading = true;
  String? _error;
  bool _started = false;
  final Set<int> _expanded = {};

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
      _expanded.clear();
    });
    final api = ApiService();
    try {
      if (_services.isEmpty) {
        try {
          _services = (await api.fetchServiceHealth()).map((s) => s.service).toList();
        } catch (_) {
          _services = [];
        }
      }
      _service ??= _services.contains('sample-app') ? 'sample-app' : (_services.isNotEmpty ? _services.first : 'sample-app');
      final lines = await api.fetchServiceLogs(_service!, minutes: _minutes, errorsOnly: _errorsOnly, limit: 200);
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load logs.';
      });
    }
  }

  String _windowLabel(int m) => m < 60 ? '$m min' : '${m ~/ 60} h';

  Color _levelColor(AppColorScheme colors, String? level) => switch (level?.toLowerCase()) {
        'error' || 'critical' || 'fatal' => colors.critical,
        'warning' || 'warn' => colors.warning,
        'debug' => colors.muted,
        _ => colors.info,
      };

  String _clock(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
        );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'Logs', subtitle: '${_service ?? '…'} · Loki · last ${_windowLabel(_minutes)}'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                chip('Errors', _errorsOnly, () {
                  _errorsOnly = true;
                  _load();
                }),
                chip('All', !_errorsOnly, () {
                  _errorsOnly = false;
                  _load();
                }),
                const SizedBox(width: 8),
                ..._windows.map((w) => chip(_windowLabel(w), _minutes == w, () {
                      _minutes = w;
                      _load();
                    })),
                if (_services.length > 1) ...[
                  const SizedBox(width: 8),
                  ..._services.map((s) => chip(s, _service == s, () {
                        _service = s;
                        _load();
                      })),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'monitor'),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.receipt_long_outlined, message: 'Loading logs…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);
    if (_lines.isEmpty) {
      return FlowMessage(
        icon: Icons.verified_outlined,
        message: _errorsOnly
            ? 'No error or warning lines in the last ${_windowLabel(_minutes)}.'
            : 'No log lines in the last ${_windowLabel(_minutes)}.',
        onRetry: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _lines.length,
        itemBuilder: (_, i) {
          final l = _lines[i];
          final open = _expanded.contains(i);
          final tone = _levelColor(colors, l.level);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => open ? _expanded.remove(i) : _expanded.add(i)),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.logBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: tone, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(_clock(l.time), style: TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', color: colors.muted)),
                      const SizedBox(width: 8),
                      Text((l.level ?? 'log').toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tone)),
                      if (l.logger != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l.logger!,
                              style: TextStyle(fontSize: 11, color: colors.muted), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      open ? l.raw : l.message,
                      maxLines: open ? null : 3,
                      overflow: open ? null : TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: colors.text, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
