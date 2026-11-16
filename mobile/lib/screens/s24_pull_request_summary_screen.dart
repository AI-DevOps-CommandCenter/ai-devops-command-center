import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 's23_developer_assistant_screen.dart';

class S24PullRequestSummaryScreen extends StatelessWidget {
  const S24PullRequestSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: PR #214 · Tune DB pool settings · Merged
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
                          'PR #214',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Tune DB pool settings',
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
                      color: colors.accent.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Merged',
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

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Metadata Card
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Branch',
                                style: TextStyle(
                                    fontSize: 14, color: colors.muted)),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12.5,
                                  color: colors.text,
                                ),
                                children: const [
                                  TextSpan(text: 'tune-db-pool'),
                                  TextSpan(text: ' → '),
                                  TextSpan(text: 'main'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildMetaRow('Author', 'Alex Morgan', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow(
                            'Reviewers', 'Priya Silva · approved', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('Checks', 'Pipeline #318 · passed', colors),
                        const SizedBox(height: 10),
                        _buildMetaRow('Deployed as', 'v2.8.1', colors,
                            isMono: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // AI Summary Card
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
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 18, color: colors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'AI summary',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildBullet(
                            'Lowers DB pool timeout from 1000 ms to 500 ms.',
                            colors),
                        const SizedBox(height: 4),
                        _buildBullet('Adds 3 connection retries.', colors),
                        const SizedBox(height: 4),
                        _buildBullet('Changes the log format.', colors),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.warning.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  fontSize: 14, color: colors.text),
                              children: const [
                                TextSpan(
                                  text: 'Risk: medium. ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text:
                                      'Timeout lowered without a load test. Linked to INC-1042.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Changed files · 3 Header
                  Text(
                    'CHANGED FILES · 3',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Changed Files Card
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildFileRow(
                          name: 'db/pool.ts',
                          additions: '+8',
                          deletions: '-2',
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 42,
                            color: colors.border),
                        _buildFileRow(
                          name: 'config/prod.yaml',
                          additions: '+3',
                          deletions: '-1',
                          colors: colors,
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 42,
                            color: colors.border),
                        _buildFileRow(
                          name: 'logger.ts',
                          additions: '+14',
                          deletions: '-9',
                          colors: colors,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Diff Snippet Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.codeBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'db/pool.ts',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12.5,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          '- timeout: 1000,',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12.5,
                            height: 1.7,
                            color: colors.critical,
                          ),
                        ),
                        Text(
                          '+ timeout: 500,',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12.5,
                            height: 1.7,
                            color: colors.ok,
                          ),
                        ),
                        Text(
                          '+ retries: 3,',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12.5,
                            height: 1.7,
                            color: colors.ok,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Ask the assistant Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const S23DeveloperAssistantScreen(),
                          ),
                        );
                      },
                      icon: Icon(Icons.auto_awesome,
                          size: 18, color: colors.text),
                      label: Text(
                        'Ask the assistant',
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

            // Bottom Nav
            const AppBottomNav(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, dynamic colors,
      {bool isMono = false}) {
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
            fontFamily: isMono ? 'JetBrains Mono' : null,
            fontSize: isMono ? 12.5 : 14,
            fontWeight: FontWeight.w500,
            color: colors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildBullet(String text, dynamic colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ',
            style: TextStyle(
                fontSize: 14, color: colors.muted, height: 1.45)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 14, color: colors.text, height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _buildFileRow({
    required String name,
    required String additions,
    required String deletions,
    required dynamic colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 18, color: colors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: colors.text,
              ),
            ),
          ),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12.5,
              ),
              children: [
                TextSpan(
                    text: additions,
                    style: TextStyle(color: colors.ok)),
                const TextSpan(text: ' '),
                TextSpan(
                    text: deletions,
                    style: TextStyle(color: colors.critical)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
