import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';

/// S25 – in-app notification feed from GET /api/notifications.
class S25NotificationsScreen extends StatefulWidget {
  const S25NotificationsScreen({super.key});

  @override
  State<S25NotificationsScreen> createState() => _S25NotificationsScreenState();
}

class _S25NotificationsScreenState extends State<S25NotificationsScreen> {
  List<NotificationModel> _items = [];
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
      final items = await ApiService().fetchNotifications(limit: 50);
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load notifications.';
        _loading = false;
      });
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.isRead) return;
    try {
      await ApiService().markNotificationAsRead(n.id);
      if (!mounted) return;
      setState(() {
        _items = _items.map((i) => i.id == n.id ? i.copyWith(readAt: DateTime.now()) : i).toList();
      });
    } catch (_) {
      // Leave it unread; the next refresh shows the server state.
    }
  }

  Future<void> _markAllRead() async {
    for (final n in _items.where((i) => !i.isRead).toList()) {
      await _markRead(n);
    }
  }

  void _open(NotificationModel n) {
    _markRead(n);
    if (n.incidentId == null || n.incidentId!.isEmpty) return;
    Navigator.pushNamed(context, n.category.targetRoute, arguments: n.incidentId);
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  bool _isToday(DateTime t) {
    final now = DateTime.now();
    final l = t.toLocal();
    return l.year == now.year && l.month == now.month && l.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = _items.where((i) => !i.isRead).length;
    final countLabel = _loading
        ? 'Loading…'
        : unread > 0
            ? '$unread unread · ${_items.length} total'
            : 'All caught up · ${_items.length} total';
    final today = _items.where((i) => _isToday(i.createdAt)).toList();
    final earlier = _items.where((i) => !_isToday(i.createdAt)).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: colors.text)),
                        const SizedBox(height: 1),
                        Text(countLabel,
                            style: TextStyle(fontSize: 13, color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: unread > 0 ? _markAllRead : null,
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: colors.accent),
                    child: const Text('Mark all read', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _buildBody(colors, today, earlier),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme colors, List<NotificationModel> today, List<NotificationModel> earlier) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 60),
        Center(child: Text(_error!, style: TextStyle(color: colors.red, fontSize: 13))),
        Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
      ]);
    }
    if (_items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 60),
        Icon(Icons.notifications_none_rounded, size: 40, color: colors.muted),
        const SizedBox(height: 8),
        Center(child: Text('No notifications yet.', style: TextStyle(fontWeight: FontWeight.bold, color: colors.text))),
        const SizedBox(height: 4),
        Center(child: Text('Approval requests and incident updates appear here.', style: TextStyle(color: colors.muted, fontSize: 13))),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (today.isNotEmpty) ...[_section(colors, 'Today'), ...today.map((n) => _card(colors, n))],
        if (earlier.isNotEmpty) ...[
          if (today.isNotEmpty) const SizedBox(height: 8),
          _section(colors, 'Earlier'),
          ...earlier.map((n) => _card(colors, n)),
        ],
      ],
    );
  }

  Widget _section(AppColorScheme colors, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: colors.muted)),
      );

  Widget _card(AppColorScheme colors, NotificationModel n) {
    final cat = n.category;
    final (Color bg, Color fg) = switch (cat) {
      NotificationCategory.approvalRequest => (colors.badgeAmberBg, colors.warning),
      NotificationCategory.incidentAlert => (colors.badgeRedBg, colors.red),
      NotificationCategory.recoveryResolution => (colors.badgeGreenBg, colors.green),
      _ => (colors.badgeTealBg, colors.accent),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _open(n),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: n.isRead ? colors.border : colors.accent.withOpacity(0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(cat.icon, size: 18, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(n.title,
                            style: TextStyle(fontSize: 14, fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700, color: colors.text)),
                      ),
                      if (!n.isRead)
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 4),
                    Text(n.message, style: TextStyle(fontSize: 13, color: colors.muted, height: 1.35)),
                    const SizedBox(height: 6),
                    Text('${cat.displayName} · ${_ago(n.createdAt)}', style: TextStyle(fontSize: 11, color: colors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
