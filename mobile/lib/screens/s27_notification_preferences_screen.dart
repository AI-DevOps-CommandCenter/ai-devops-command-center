import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S27NotificationPreferencesScreen extends StatefulWidget {
  const S27NotificationPreferencesScreen({super.key});

  @override
  State<S27NotificationPreferencesScreen> createState() =>
      _S27NotificationPreferencesScreenState();
}

class _S27NotificationPreferencesScreenState
    extends State<S27NotificationPreferencesScreen> {
  final Map<String, bool> _state = {
    'detectPush': true,
    'detectEmail': false,
    'detectSlack': true,
    'detectDiscord': false,
    'approvePush': true,
    'approveEmail': true,
    'approveSlack': true,
    'approveDiscord': false,
    'resultPush': true,
    'resultEmail': false,
    'resultSlack': true,
    'resultDiscord': false,
    'resolvePush': true,
    'resolveEmail': true,
    'resolveSlack': true,
    'resolveDiscord': false,
  };

  final List<Map<String, String>> _events = const [
    {'k': 'detect', 'n': 'Incident detected'},
    {'k': 'approve', 'n': 'Approval needed'},
    {'k': 'result', 'n': 'Action result'},
    {'k': 'resolve', 'n': 'Incident resolved'},
  ];

  final List<String> _channels = const ['Push', 'Email', 'Slack', 'Discord'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Notifications · Choose where each event goes
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
                          'Notifications',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Choose where each event goes',
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
                  // Table Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Event',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                              ..._channels.map((c) => SizedBox(
                                    width: 48,
                                    child: Text(
                                      c,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.muted,
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        // Table Rows
                        ..._events.map((ev) {
                          final k = ev['k']!;
                          final name = ev['n']!;
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: colors.border),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                ),
                                ..._channels.map((c) {
                                  final key = '$k$c';
                                  final isOn = _state[key] ?? false;
                                  return SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _state[key] = !isOn;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(7),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: isOn
                                                ? colors.accent
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(7),
                                            border: Border.all(
                                              color: isOn
                                                  ? colors.accent
                                                  : colors.muted,
                                              width: 2,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: isOn
                                              ? Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: colors.onAccent,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Footnote
                  Text(
                    'Push uses Firebase Cloud Messaging. Discord needs a webhook in Integrations.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.muted,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quiet hours Header
                  Text(
                    'QUIET HOURS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.52,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quiet Hours Card
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
                            Text(
                              'Mute non-critical',
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.muted,
                              ),
                            ),
                            Text(
                              '22:00 – 07:00',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Critical alerts',
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.muted,
                              ),
                            ),
                            Text(
                              'Always deliver',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save',
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
          ],
        ),
      ),
    );
  }
}
