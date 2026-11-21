import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';

/// S37 – team members and their roles (admins; GET /api/admin/users).
/// Admins can change another user's role (PATCH /api/admin/users/:id/role).
class S37TeamScreen extends StatefulWidget {
  const S37TeamScreen({super.key});

  @override
  State<S37TeamScreen> createState() => _S37TeamScreenState();
}

class _S37TeamScreenState extends State<S37TeamScreen> {
  static const _roles = ['admin', 'operator', 'user'];
  List<Map<String, dynamic>> _users = [];
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
      final users = await ApiService().fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load the team.';
      });
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change role?'),
        content: Text('${user['email']} will become "$role".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Change')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().updateUserRole(user['id'].toString(), role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role changed to $role.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Could not change the role.')));
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
            FlowHeader(title: 'Team', subtitle: _loading ? 'Loading…' : '${_users.length} accounts'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.group_outlined, message: 'Loading team…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.error_outline, message: _error!, onRetry: _load);
    final me = AuthService().currentUser?.id;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: _users.map((u) {
          final role = u['role']?.toString() ?? '—';
          final email = u['email']?.toString() ?? '—';
          final name = (u['full_name']?.toString().trim().isNotEmpty ?? false) ? u['full_name'].toString() : email;
          final editable = u['id'] != me && _roles.contains(role);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FlowCard(
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.accentSoft,
                  child: Text(name[0].toUpperCase(), style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                    if (name != email) Text(email, style: TextStyle(fontSize: 12, color: colors.muted)),
                  ]),
                ),
                if (editable)
                  PopupMenuButton<String>(
                    initialValue: role,
                    onSelected: (r) => r == role ? null : _changeRole(u, r),
                    itemBuilder: (_) => _roles.map((r) => PopupMenuItem(value: r, child: Text(r))).toList(),
                    child: Row(children: [
                      Text(role, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.accent)),
                      Icon(Icons.arrow_drop_down, color: colors.accent),
                    ]),
                  )
                else
                  Text(u['id'] == me ? '$role (you)' : role, style: TextStyle(fontSize: 13, color: colors.muted)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}
