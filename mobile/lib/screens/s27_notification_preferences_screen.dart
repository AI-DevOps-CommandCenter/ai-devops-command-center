import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S27NotificationPreferencesScreen extends StatefulWidget {
  const S27NotificationPreferencesScreen({super.key});

  @override
  State<S27NotificationPreferencesScreen> createState() => _S27NotificationPreferencesScreenState();
}

class _S27NotificationPreferencesScreenState extends State<S27NotificationPreferencesScreen> {
  final Map<String, bool> _preferences = {
    'Push-Detection': true,
    'Push-Approval requests': true,
    'Push-Action results': true,
    'Push-Resolution': true,
    'Email-Detection': true,
    'Email-Approval requests': true,
    'Email-Action results': false,
    'Email-Resolution': true,
    'Slack-Detection': true,
    'Slack-Approval requests': true,
    'Slack-Action results': true,
    'Slack-Resolution': true,
    'Discord-Detection': false,
    'Discord-Approval requests': false,
    'Discord-Action results': false,
    'Discord-Resolution': false,
  };

  final List<String> _channels = const ['Push', 'Email', 'Slack', 'Discord'];
  final List<String> _events = const [
    'Detection',
    'Approval requests',
    'Action results',
    'Resolution',
  ];

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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.text, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Preferences',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._channels.map((channel) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.cardBorder, width: 0.8),
                            boxShadow: [
                              BoxShadow(
                                color: colors.isDark ? Colors.black.withOpacity(0.3) : const Color.fromRGBO(15, 27, 51, 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ..._events.map((event) {
                                final key = '$channel-$event';
                                final isChecked = _preferences[key] ?? false;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        event,
                                        style: TextStyle(fontSize: 13, color: colors.text),
                                      ),
                                      Switch.adaptive(
                                        value: isChecked,
                                        activeColor: colors.teal,
                                        onChanged: (val) {
                                          setState(() {
                                            _preferences[key] = val;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Preferences saved successfully!'),
                              backgroundColor: colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.teal,
                          foregroundColor: colors.isDark ? const Color(0xFF0B1226) : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save changes',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 's28'),
    );
  }
}
