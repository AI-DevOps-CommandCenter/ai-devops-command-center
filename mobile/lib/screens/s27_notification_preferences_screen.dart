import 'package:flutter/material.dart';
import '../services/api_service.dart' show ApiException;
import '../services/notification_preferences_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';

/// S27 – the signed-in user's notification settings
/// (GET/PUT /api/notifications/preferences, stored in notification_preferences).
///
/// In-app: always on (the inbox, S25).
/// Push and email: per user. The database applies them to every notification
/// it writes for this user (write_notification).
/// Slack and Discord: team channels, configured on the server (read-only here).
class S27NotificationPreferencesScreen extends StatefulWidget {
  final NotificationPreferencesService? service;
  const S27NotificationPreferencesScreen({super.key, this.service});

  @override
  State<S27NotificationPreferencesScreen> createState() => _S27NotificationPreferencesScreenState();
}

class _S27NotificationPreferencesScreenState extends State<S27NotificationPreferencesScreen> {
  late final NotificationPreferencesService _service = widget.service ?? NotificationPreferencesService();
  NotificationPreferences? _prefs;
  String? _loadError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final prefs = await _service.load();
      if (mounted) setState(() => _prefs = prefs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  Future<void> _change({bool? push, bool? email}) async {
    final before = _prefs!;
    final wanted = before.copyWith(pushEnabled: push, emailEnabled: email);
    setState(() {
      _prefs = wanted; // show the change at once; undone if saving fails
      _saving = true;
      _saveError = null;
    });
    try {
      final saved = await _service.save(pushEnabled: wanted.pushEnabled, emailEnabled: wanted.emailEnabled);
      if (mounted) setState(() => _prefs = saved);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _prefs = before;
          _saveError = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prefs = _prefs;

    Widget body;
    if (_loadError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_outlined, color: colors.muted, size: 36),
            const SizedBox(height: 10),
            Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: colors.text, fontSize: 14)),
            const SizedBox(height: 12),
            OutlinedButton(key: const Key('prefs-retry'), onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );
    } else if (prefs == null) {
      body = Center(child: CircularProgressIndicator(color: colors.accent));
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _section(colors, 'Your channels'),
          _channel(colors,
              icon: Icons.notifications_active_outlined,
              title: 'In-app',
              subtitle: 'Every notification appears in your inbox. Always on.',
              trailing: _badge(colors, 'Always on', colors.success)),
          _channel(colors,
              icon: Icons.phone_iphone,
              title: 'Push notifications',
              subtitle: prefs.server.push
                  ? 'Approval requests and run results on this phone.'
                  : 'Saved now; push delivery starts when the server push sender is set up.',
              trailing: Switch(
                key: const Key('prefs-push'),
                value: prefs.pushEnabled,
                onChanged: _saving ? null : (v) => _change(push: v),
              )),
          _channel(colors,
              icon: Icons.mail_outline,
              title: 'Email',
              subtitle: prefs.server.email
                  ? 'A copy of each notification to your account email.'
                  : 'Saved now; emails are sent once SMTP is configured on the server.',
              trailing: Switch(
                key: const Key('prefs-email'),
                value: prefs.emailEnabled,
                onChanged: _saving ? null : (v) => _change(email: v),
              )),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_saveError!, key: const Key('prefs-save-error'), style: TextStyle(color: colors.critical, fontSize: 13)),
            ),
          const SizedBox(height: 8),
          _section(colors, 'Team channels'),
          _channel(colors,
              icon: Icons.tag,
              title: 'Slack',
              subtitle: 'Incident updates for the whole team. Set on the server (SLACK_WEBHOOK_URL).',
              trailing: _serverBadge(colors, prefs.server.slack)),
          _channel(colors,
              icon: Icons.forum_outlined,
              title: 'Discord',
              subtitle: 'Incident updates for the whole team. Set on the server (DISCORD_WEBHOOK_URL).',
              trailing: _serverBadge(colors, prefs.server.discord)),
          const SizedBox(height: 6),
          Text(
            prefs.updatedAt == null
                ? 'You have not changed these settings yet; the defaults are shown.'
                : 'Saved ${_formatTime(prefs.updatedAt!)}.',
            key: const Key('prefs-saved-at'),
            style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          const FlowHeader(title: 'Notifications', subtitle: 'Delivery channels'),
          Expanded(child: body),
        ]),
      ),
    );
  }

  Widget _section(AppColorScheme colors, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: colors.muted)),
      );

  Widget _channel(AppColorScheme colors,
          {required IconData icon, required String title, required String subtitle, required Widget trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FlowCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(icon, color: colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 13, color: colors.muted, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 8),
            trailing,
          ]),
        ),
      );

  Widget _badge(AppColorScheme colors, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _serverBadge(AppColorScheme colors, bool configured) =>
      _badge(colors, configured ? 'Connected' : 'Not set up', configured ? colors.success : colors.muted);

  static String _formatTime(DateTime t) {
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
