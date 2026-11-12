import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S37TeamScreen extends StatefulWidget {
  const S37TeamScreen({super.key});

  @override
  State<S37TeamScreen> createState() => _S37TeamScreenState();
}

class _S37TeamScreenState extends State<S37TeamScreen> {
  bool _inviting = false;
  bool _sent = false;

  final TextEditingController _emailController =
      TextEditingController(text: 'new.member@demo.dev');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendInvite() {
    setState(() {
      _inviting = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Team and roles · 5 members · Group 33 workspace
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
                          'Team and roles',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '5 members · Group 33 workspace',
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
                  // Members Card
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildMemberRow(
                          initials: 'AM',
                          name: 'Alex Morgan',
                          role: 'Tech lead',
                          badgeText: 'Approver',
                          badgeBg: colors.accent.withOpacity(0.16),
                          badgeFg: colors.accent,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildMemberRow(
                          initials: 'SP',
                          name: 'Sam Perera',
                          role: 'Admin',
                          badgeText: 'Admin',
                          badgeBg: colors.info.withOpacity(0.14),
                          badgeFg: colors.info,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildMemberRow(
                          initials: 'PS',
                          name: 'Priya Silva',
                          role: 'Developer',
                          badgeText: 'Approver',
                          badgeBg: colors.accent.withOpacity(0.16),
                          badgeFg: colors.accent,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildMemberRow(
                          initials: 'NJ',
                          name: 'Nuwan Jayasuriya',
                          role: 'DevOps engineer',
                          badgeText: 'Responder',
                          badgeBg: colors.cardSecondary,
                          badgeFg: colors.muted,
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 46,
                            color: colors.border),
                        _buildMemberRow(
                          initials: 'KF',
                          name: 'Kavya Fernando',
                          role: 'Developer',
                          badgeText: 'Viewer',
                          badgeBg: colors.cardSecondary,
                          badgeFg: colors.muted,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // What each role can do Header
                  Text(
                    'WHAT EACH ROLE CAN DO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // What each role can do Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRoleBullet('Admin', ': accounts, integrations, playbooks', colors),
                        const SizedBox(height: 6),
                        _buildRoleBullet('Approver', ': approve high-impact playbooks', colors),
                        const SizedBox(height: 6),
                        _buildRoleBullet('Responder', ': investigate, run low-impact playbooks', colors),
                        const SizedBox(height: 6),
                        _buildRoleBullet('Viewer', ': read only', colors),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Invite member section / status
                  if (_sent) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.ok.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Invite sent to new.member@demo.dev',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_inviting) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                            ),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: _emailController,
                              style:
                                  TextStyle(fontSize: 15, color: colors.text),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Role: Responder',
                            style:
                                TextStyle(fontSize: 14, color: colors.muted),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _sendInvite,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.accent,
                                foregroundColor: colors.onAccent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Send invite',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _inviting = true;
                          });
                        },
                        icon: Icon(Icons.person_add_alt_1_outlined,
                            size: 18, color: colors.text),
                        label: Text(
                          'Invite member',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow({
    required String initials,
    required String name,
    required String role,
    required String badgeText,
    required Color badgeBg,
    required Color badgeFg,
    required dynamic colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.cardSecondary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
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
                  role,
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
                color: badgeFg,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBullet(String strong, String rest, dynamic colors) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: colors.text, height: 1.45),
        children: [
          TextSpan(
            text: strong,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: rest),
        ],
      ),
    );
  }
}
