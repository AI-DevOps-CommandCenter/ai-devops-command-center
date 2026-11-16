import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 's27_notification_preferences_screen.dart';

class S26IntegrationsScreen extends StatefulWidget {
  const S26IntegrationsScreen({super.key});

  @override
  State<S26IntegrationsScreen> createState() => _S26IntegrationsScreenState();
}

class _S26IntegrationsScreenState extends State<S26IntegrationsScreen> {
  String _lokiStatus = 'fail'; // 'fail', 'busy', 'ok'

  void _retryLoki() {
    setState(() {
      _lokiStatus = 'busy';
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _lokiStatus = 'ok';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final summary =
        _lokiStatus == 'ok' ? 'All 8 healthy' : '7 of 8 healthy';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Integrations · summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_left, size: 20, color: colors.text),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Integrations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          summary,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Core Integrations List Card
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildIntegrationRow(
                          name: 'GitHub',
                          desc: 'Commits, PRs, pipelines',
                          isGood: true,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildIntegrationRow(
                          name: 'GitLab',
                          desc: 'orders-worker repo',
                          isGood: true,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildIntegrationRow(
                          name: 'Prometheus',
                          desc: 'Metrics · 30 s scrape',
                          isGood: true,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildLokiRow(colors),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildIntegrationRow(
                          name: 'n8n',
                          desc: '3 investigation workflows',
                          isGood: true,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildIntegrationRow(
                          name: 'Groq API',
                          desc: 'Log and root-cause analysis',
                          isGood: true,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildIntegrationRow(
                          name: 'Supabase',
                          desc: 'Incidents and audit data',
                          isGood: true,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildIntegrationRow(
                          name: 'Firebase (FCM)',
                          desc: 'Push notifications',
                          isGood: true,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notification channels Header
                  Text(
                    'NOTIFICATION CHANNELS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Notification Channels Card
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const S27NotificationPreferencesScreen(),
                              ),
                            );
                          },
                          child: _buildChannelRow(
                            icon: Icons.chat_bubble_outline,
                            name: 'Slack',
                            desc: '#payments-oncall · webhook',
                            badgeText: 'Connected',
                            badgeColor: colors.ok,
                            badgeBg: colors.ok.withOpacity(0.13),
                            colors: colors,
                          ),
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const S27NotificationPreferencesScreen(),
                              ),
                            );
                          },
                          child: _buildChannelRow(
                            icon: Icons.chat_bubble_outline,
                            name: 'Discord',
                            desc: 'Not connected',
                            badgeText: 'Connect',
                            badgeColor: colors.accent,
                            badgeBg: colors.accent.withOpacity(0.16),
                            colors: colors,
                          ),
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const S27NotificationPreferencesScreen(),
                              ),
                            );
                          },
                          child: _buildChannelRow(
                            icon: Icons.mail_outline,
                            name: 'Email',
                            desc: 'alex.morgan@demo.dev',
                            badgeText: 'Connected',
                            badgeColor: colors.ok,
                            badgeBg: colors.ok.withOpacity(0.13),
                            colors: colors,
                          ),
                        ),
                      ],
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

  Widget _buildIntegrationRow({
    required String name,
    required String desc,
    required bool isGood,
    required dynamic colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.power_outlined, size: 20, color: colors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (isGood)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: colors.ok.withOpacity(0.13),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Connected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.ok,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLokiRow(dynamic colors) {
    String desc;
    if (_lokiStatus == 'ok') {
      desc = 'Synced just now';
    } else if (_lokiStatus == 'busy') {
      desc = 'Retrying…';
    } else {
      desc = 'Last sync 2 h ago · check credentials';
    }

    final isGood = _lokiStatus == 'ok';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.power_outlined, size: 20, color: colors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loki',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (isGood)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: colors.ok.withOpacity(0.13),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Connected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.ok,
                  height: 1.5,
                ),
              ),
            )
          else
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: _lokiStatus == 'busy' ? null : _retryLoki,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.critical,
                  foregroundColor: colors.card,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _lokiStatus == 'busy' ? 'Retrying…' : 'Retry',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelRow({
    required IconData icon,
    required String name,
    required String desc,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required dynamic colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badgeColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
