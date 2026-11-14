import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S39AuditLogScreen extends StatefulWidget {
  const S39AuditLogScreen({super.key});

  @override
  State<S39AuditLogScreen> createState() => _S39AuditLogScreenState();
}

class _S39AuditLogScreenState extends State<S39AuditLogScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Audit log · Today · stored in Supabase
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
                          'Audit log',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Today · stored in Supabase',
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
                  // Audit Log List Card
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildAuditRow(
                          icon: Icons.check,
                          iconColor: colors.ok,
                          iconBg: colors.ok.withOpacity(0.13),
                          title: 'Verified recovery of payments-api',
                          author: 'System',
                          time: '14:33',
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildAuditRow(
                          icon: Icons.play_arrow,
                          iconColor: colors.info,
                          iconBg: colors.info.withOpacity(0.14),
                          title:
                              'Ran playbook Roll back deployment (v2.8.1 → v2.8.0)',
                          author: 'System',
                          time: '14:25',
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildAuditRow(
                          icon: Icons.lock_outline,
                          iconColor: colors.warning,
                          iconBg: colors.warning.withOpacity(0.14),
                          title: 'Approved rollback for INC-1042',
                          author: 'Alex Morgan',
                          time: '14:24',
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildAuditRow(
                          icon: Icons.auto_awesome,
                          iconColor: colors.accent,
                          iconBg: colors.accent.withOpacity(0.16),
                          title: 'Recommended Roll back deployment',
                          author: 'AI (Groq via n8n)',
                          time: '14:15',
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildAuditRow(
                          icon: Icons.warning_amber_rounded,
                          iconColor: colors.critical,
                          iconBg: colors.critical.withOpacity(0.14),
                          title: 'Opened INC-1042 · error rate above 5%',
                          author: 'Prometheus',
                          time: '14:12',
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildAuditRow(
                          icon: Icons.edit_outlined,
                          iconColor: colors.muted,
                          iconBg: colors.cardSecondary,
                          title: 'Changed Scale service limit to 6 replicas',
                          author: 'Sam Perera (admin)',
                          time: '09:10',
                          colors: colors,
                        ),
                      ],
                    ),
                  ),

                  if (_done) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.ok.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'audit-log-today.csv sent to alex.morgan@demo.dev',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Export as CSV Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _done = true;
                        });
                      },
                      icon: Icon(Icons.insert_drive_file_outlined,
                          size: 18, color: colors.text),
                      label: Text(
                        'Export as CSV',
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

  Widget _buildAuditRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String author,
    required String time,
    required dynamic colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: colors.muted),
                    children: [
                      TextSpan(text: '$author · '),
                      TextSpan(
                        text: time,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12.5,
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
    );
  }
}
