import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';
import 's38_playbook_edit_screen.dart';

/// S16 – the reviewed remediation playbooks (GET /api/admin/playbooks).
/// Only enabled playbooks can be requested; admins can open one to edit it.
class S16RemediationPlaybooksScreen extends StatefulWidget {
  const S16RemediationPlaybooksScreen({super.key});

  @override
  State<S16RemediationPlaybooksScreen> createState() => _S16RemediationPlaybooksScreenState();
}

class _S16RemediationPlaybooksScreenState extends State<S16RemediationPlaybooksScreen> {
  List<Map<String, dynamic>> _playbooks = [];
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
      final list = await ApiService().fetchPlaybooks();
      list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      if (!mounted) return;
      setState(() {
        _playbooks = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load playbooks.';
      });
    }
  }

  IconData _icon(String? action) => switch (action) {
        'restart' => Icons.restart_alt,
        'circuit_breaker' => Icons.power_off_outlined,
        'rollback' => Icons.undo,
        'scale' => Icons.open_in_full,
        _ => Icons.playlist_play,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isAdmin = AuthService().currentUser?.isAdmin ?? false;
    final enabled = _playbooks.where((p) => p['enabled'] == true).length;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(
              title: 'Playbooks',
              subtitle: _loading ? 'Loading…' : '$enabled of ${_playbooks.length} enabled',
            ),
            Expanded(child: _body(colors, isAdmin)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColorScheme colors, bool isAdmin) {
    if (_loading) return const FlowMessage(icon: Icons.playlist_play, message: 'Loading playbooks…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);
    if (_playbooks.isEmpty) return FlowMessage(icon: Icons.playlist_play, message: 'No playbooks yet.', onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'The AI can only recommend one of these reviewed playbooks, and each run still needs a human approval.',
            style: TextStyle(fontSize: 13, color: colors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          ..._playbooks.map((p) {
            final on = p['enabled'] == true;
            final action = p['action_type']?.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: !isAdmin
                    ? null
                    : () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => S38PlaybookEditScreen(playbook: p)),
                        );
                        if (changed == true) _load();
                      },
                child: FlowCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icon(action), color: on ? colors.accent : colors.muted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name']?.toString() ?? '—',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                            const SizedBox(height: 3),
                            Text(p['description']?.toString() ?? '',
                                style: TextStyle(fontSize: 13, color: colors.muted, height: 1.35)),
                            const SizedBox(height: 6),
                            Text(
                              '${action ?? '—'} · ${p['requires_approval'] == false ? 'no approval' : 'approval required'}',
                              style: TextStyle(fontSize: 11, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (on ? colors.success : colors.muted).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(on ? 'enabled' : 'disabled',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? colors.success : colors.muted)),
                      ),
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
