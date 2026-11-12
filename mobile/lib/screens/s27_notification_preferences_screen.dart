import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S27NotificationPreferencesScreen extends StatefulWidget {
  const S27NotificationPreferencesScreen({super.key});

  @override
  State<S27NotificationPreferencesScreen> createState() => _S27NotificationPreferencesScreenState();
}

class _S27NotificationPreferencesScreenState extends State<S27NotificationPreferencesScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, bool> _preferences = {
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
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _apiService.fetchNotificationPreferences();
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    await _apiService.saveNotificationPreferences(_preferences);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Notification preferences saved successfully!'),
            ],
          ),
          backgroundColor: context.colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  IconData _getChannelIcon(String channel) {
    switch (channel) {
      case 'Push':
        return Icons.notifications_active_outlined;
      case 'Email':
        return Icons.mail_outline_rounded;
      case 'Slack':
        return Icons.tag_rounded;
      case 'Discord':
        return Icons.forum_outlined;
      default:
        return Icons.notifications_none_rounded;
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preferences',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'Notification channels & alert triggers',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.cardAccent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border, width: 0.8),
                    ),
                    child: Text(
                      'S27',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.teal))
                  : SingleChildScrollView(
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
                                      color: colors.isDark
                                          ? Colors.black.withOpacity(0.3)
                                          : const Color.fromRGBO(15, 27, 51, 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_getChannelIcon(channel), size: 18, color: colors.teal),
                                        const SizedBox(width: 8),
                                        Text(
                                          channel,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: colors.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
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
                              onPressed: _isSaving ? null : _savePreferences,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.teal,
                                foregroundColor: colors.isDark ? const Color(0xFF0B1226) : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
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
