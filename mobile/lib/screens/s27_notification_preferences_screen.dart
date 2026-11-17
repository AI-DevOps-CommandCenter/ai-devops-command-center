import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';

/// S27 – how notifications reach people. Read-only: delivery is decided by the
/// database (notify_approvers → in_app + push) and the backend's notification
/// worker; per-user preferences are not stored yet (future work).
class S27NotificationPreferencesScreen extends StatelessWidget {
  const S27NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final channels = [
      (Icons.notifications_active_outlined, 'In-app', 'On', colors.success,
          'Approvers get an in-app notification for every remediation request (S25).'),
      (Icons.phone_iphone, 'Push (FCM)', 'Queued', colors.warning,
          'Push deliveries are queued in the database; the Firebase sender is future work.'),
      (Icons.mail_outline, 'Email', 'Server', colors.muted,
          'Sent by the backend notification worker when SMTP is configured.'),
      (Icons.tag, 'Slack', 'Server', colors.muted, 'Sent by the notification worker when SLACK_WEBHOOK_URL is set.'),
      (Icons.forum_outlined, 'Discord', 'Server', colors.muted, 'Sent by the notification worker when DISCORD_WEBHOOK_URL is set.'),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const FlowHeader(title: 'Notifications', subtitle: 'Delivery channels'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  ...channels.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FlowCard(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(c.$1, color: colors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                                const SizedBox(height: 3),
                                Text(c.$5, style: TextStyle(fontSize: 13, color: colors.muted, height: 1.35)),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: c.$4.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(c.$3, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.$4)),
                            ),
                          ]),
                        ),
                      )),
                  const SizedBox(height: 6),
                  Text(
                    'Per-user channel preferences are not stored yet; every approver receives approval requests in-app.',
                    style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
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
