import 'package:flutter/material.dart';
import '../services/api_endpoints.dart';
import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';
import 's16_remediation_playbooks_screen.dart';
import 's22_incident_history_screen.dart';
import 's26_integrations_screen.dart';
import 's27_notification_preferences_screen.dart';
import 's37_team_screen.dart';
import 's39_audit_log_screen.dart';

/// S28 – signed-in user (role from GET /api/me → public.profiles) and the
/// settings / admin menu. Admin-only entries are hidden for other roles; the
/// database enforces the same rules.
class S28ProfileScreen extends StatelessWidget {
  const S28ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = AuthService().currentUser;
    final name = user?.name ?? 'Signed out';
    final initials = name
        .split(RegExp(r'[\s._@-]+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    void open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    Widget item(IconData icon, String title, String sub, Widget screen) => InkWell(
          onTap: () => open(screen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(icon, size: 20, color: colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                  Text(sub, style: TextStyle(fontSize: 12, color: colors.muted)),
                ]),
              ),
              Icon(Icons.chevron_right, color: colors.muted),
            ]),
          ),
        );

    Widget group(List<Widget> items) => Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                items[i],
              ],
            ],
          ),
        );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const FlowHeader(title: 'Profile', subtitle: 'Account and settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  FlowCard(
                    child: Row(children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: colors.accent,
                        child: Text(initials.isEmpty ? '?' : initials,
                            style: TextStyle(fontWeight: FontWeight.w700, color: colors.onAccent)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.text)),
                          const SizedBox(height: 2),
                          Text(user?.email ?? '—', style: TextStyle(fontSize: 13, color: colors.muted)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(99)),
                            child: Text(user?.roleLabel ?? '—',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.accent)),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  group([
                    item(Icons.notifications_active_outlined, 'Notification preferences', 'Channels and alert types',
                        const S27NotificationPreferencesScreen()),
                    item(Icons.history, 'Incident history', 'Resolved and closed incidents', const S22IncidentHistoryScreen()),
                  ]),
                  const SizedBox(height: 12),
                  group([
                    item(Icons.playlist_play, 'Remediation playbooks', 'Fixes the AI can recommend',
                        const S16RemediationPlaybooksScreen()),
                    item(Icons.hub_outlined, 'Integrations', 'Connected monitoring and code services',
                        const S26IntegrationsScreen()),
                    if (user?.canOperate ?? false)
                      item(Icons.fact_check_outlined, 'Audit log', 'Who did what, and when', const S39AuditLogScreen()),
                    if (user?.isAdmin ?? false) item(Icons.group_outlined, 'Team', 'Users and roles', const S37TeamScreen()),
                  ]),
                  const SizedBox(height: 16),
                  FlowCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BACKEND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: colors.muted)),
                      const SizedBox(height: 6),
                      Text(ApiEndpoints.baseUrl, style: TextStyle(fontSize: 13, color: colors.text)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Unregisters this device's push token first, then ends the session.
                        await AuthController.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.text,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
