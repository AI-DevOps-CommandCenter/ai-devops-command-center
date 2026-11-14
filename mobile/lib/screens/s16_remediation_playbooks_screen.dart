import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/proto_icon.dart';
import 's38_playbook_edit_screen.dart';

class S16RemediationPlaybooksScreen extends StatelessWidget {
  const S16RemediationPlaybooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Playbooks · Admins review and edit · 4 active
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
                          'Playbooks',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Admins review and edit · 4 active',
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
                  // Info banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.info.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProtoIcon(ProtoIcons.shieldCheck,
                            size: 18, color: colors.info),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The AI can only recommend these playbooks. Anything else must be done outside the app.',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.text,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 1. Restart service
                  _buildPlaybookCard(
                    context,
                    icon: Icons.refresh,
                    svg: ProtoIcons.restart,
                    title: 'Restart service',
                    desc: 'Restarts pods one at a time.',
                    impactLabel: 'Medium impact',
                    impactBg: colors.warning.withOpacity(0.14),
                    impactFg: colors.warning,
                    approvalLabel: 'Approval: tech lead',
                    hasApproval: true,
                    lastRun: 'Last run 3 days ago',
                    colors: colors,
                  ),

                  const SizedBox(height: 14),

                  // 2. Roll back deployment
                  _buildPlaybookCard(
                    context,
                    icon: Icons.layers_outlined,
                    svg: ProtoIcons.layers,
                    title: 'Roll back deployment',
                    desc: 'Redeploys the last healthy version.',
                    impactLabel: 'High impact',
                    impactBg: colors.critical.withOpacity(0.14),
                    impactFg: colors.critical,
                    approvalLabel: 'Approval: tech lead',
                    hasApproval: true,
                    lastRun: 'Last run today 14:24',
                    colors: colors,
                  ),

                  const SizedBox(height: 14),

                  // 3. Scale service
                  _buildPlaybookCard(
                    context,
                    icon: Icons.scale_outlined,
                    svg: ProtoIcons.scale,
                    title: 'Scale service',
                    desc: 'Adds replicas, up to a set limit.',
                    impactLabel: 'Low impact',
                    impactBg: colors.ok.withOpacity(0.13),
                    impactFg: colors.ok,
                    approvalLabel: 'Runs without approval',
                    hasApproval: false,
                    lastRun: 'Last run 6 days ago',
                    colors: colors,
                  ),

                  const SizedBox(height: 14),

                  // 4. Enable circuit breaker
                  _buildPlaybookCard(
                    context,
                    icon: Icons.power_settings_new_outlined,
                    svg: ProtoIcons.circuitBreaker,
                    title: 'Enable circuit breaker',
                    desc: 'Stops calls to a failing dependency.',
                    impactLabel: 'Medium impact',
                    impactBg: colors.warning.withOpacity(0.14),
                    impactFg: colors.warning,
                    approvalLabel: 'Approval: tech lead',
                    hasApproval: true,
                    lastRun: 'Never run',
                    colors: colors,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybookCard(
    BuildContext context, {
    required IconData icon,
    String? svg,
    required String title,
    required String desc,
    required String impactLabel,
    required Color impactBg,
    required Color impactFg,
    required String approvalLabel,
    required bool hasApproval,
    required String lastRun,
    required dynamic colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: svg != null
                    ? ProtoIcon(svg, size: 20, color: colors.accent)
                    : Icon(icon, size: 20, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const S38PlaybookEditScreen(),
                    ),
                  );
                },
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
                  child: Icon(Icons.edit_outlined, size: 18, color: colors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: impactBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  impactLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: impactFg,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.cardSecondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasApproval) ...[
                      Icon(Icons.lock_outline, size: 13, color: colors.muted),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      approvalLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lastRun,
            style: TextStyle(
              fontSize: 12,
              color: colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
