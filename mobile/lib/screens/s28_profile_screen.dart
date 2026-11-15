import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import 's16_remediation_playbooks_screen.dart';
import 's26_integrations_screen.dart';
import 's27_notification_preferences_screen.dart';
import 's37_team_screen.dart';
import 's39_audit_log_screen.dart';

class S28ProfileScreen extends StatefulWidget {
  const S28ProfileScreen({super.key});

  @override
  State<S28ProfileScreen> createState() => _S28ProfileScreenState();
}

class _S28ProfileScreenState extends State<S28ProfileScreen> {
  late String _mode;

  @override
  void initState() {
    super.initState();
    final current = ThemeController.instance.themeMode;
    if (current == ThemeMode.dark) {
      _mode = 'Dark';
    } else if (current == ThemeMode.light) {
      _mode = 'Light';
    } else {
      _mode = 'System';
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
            // Header
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
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: colors.text,
                      ),
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
                  // User Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'AM',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.onAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alex Morgan',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: colors.text,
                                ),
                              ),
                              Text(
                                'alex.morgan@demo.dev',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.accent.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Tech lead · Approver',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // General Section Header
                  Text(
                    'GENERAL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // General Card (Notifications, Integrations)
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.notifications_none,
                                    size: 20, color: colors.muted),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Notifications',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                      Text(
                                        'Push, Email, Slack · Discord off',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18, color: colors.muted),
                              ],
                            ),
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
                                    const S26IntegrationsScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.power_outlined,
                                    size: 20, color: colors.muted),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Integrations',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                      Text(
                                        '7 of 8 healthy · Loki needs attention',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.critical.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.critical,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right,
                                    size: 18, color: colors.muted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Admin Section Header
                  Text(
                    'ADMIN',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Admin Card (Playbooks, Team, Audit log)
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
                                    const S16RemediationPlaybooksScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.auto_stories_outlined,
                                    size: 20, color: colors.muted),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Playbooks',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                      Text(
                                        '4 reviewed recovery actions',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18, color: colors.muted),
                              ],
                            ),
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
                                builder: (context) => const S37TeamScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.group_outlined,
                                    size: 20, color: colors.muted),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Team and roles',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                      Text(
                                        '5 members · 2 approvers',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18, color: colors.muted),
                              ],
                            ),
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
                                    const S39AuditLogScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.format_list_bulleted,
                                    size: 20, color: colors.muted),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Audit log',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                      Text(
                                        'Every approval and action',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18, color: colors.muted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Appearance Section Header
                  Text(
                    'APPEARANCE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Theme Segmented Control
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.cardSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: ['System', 'Dark', 'Light'].map((m) {
                        final isSelected = _mode == m;
                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _mode = m;
                              });
                              if (m == 'System') {
                                ThemeController.instance
                                    .setThemeMode(ThemeMode.system);
                              } else if (m == 'Dark') {
                                ThemeController.instance
                                    .setThemeMode(ThemeMode.dark);
                              } else {
                                ThemeController.instance
                                    .setThemeMode(ThemeMode.light);
                              }
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: colors.card,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromRGBO(0, 0, 0, 0.18),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    )
                                  : null,
                              child: Text(
                                m,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? colors.text : colors.muted,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // About DCC Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const BrandLogo(size: 44),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Command Center',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: colors.text,
                                  ),
                                ),
                                Text(
                                  'AI-powered mobile DevOps',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildMetaRow('App version', '1.0.0', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('Environment', 'Group 33', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('Project', 'Group 33', colors),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sign out button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/signin',
                          (route) => false,
                        );
                      },
                      icon: Icon(Icons.logout, size: 18, color: colors.text),
                      label: Text(
                        'Sign out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.card,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colors.border),
                        ),
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

  Widget _buildMetaRow(String label, String value, dynamic colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: colors.muted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.text,
          ),
        ),
      ],
    );
  }
}
