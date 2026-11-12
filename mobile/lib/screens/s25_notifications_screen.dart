import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S25NotificationsScreen extends StatefulWidget {
  const S25NotificationsScreen({super.key});

  @override
  State<S25NotificationsScreen> createState() => _S25NotificationsScreenState();
}

class _S25NotificationsScreenState extends State<S25NotificationsScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _activeFilter = 'All'; // 'All', 'Unread', 'Critical'

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final list = await _apiService.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // 1. Mark as read on backend (PATCH /api/notifications/:id/read)
    if (!notification.isRead) {
      await _apiService.markNotificationAsRead(notification.id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notification.id);
        if (idx != -1) {
          _notifications[idx] = notification.copyWith(readAt: DateTime.now());
        }
      });
    }

    // 2. Trigger deep linking to the target screen
    if (mounted) {
      _notificationService.handleDeepLink(context, notification);
    }
  }

  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications.map((n) {
        if (!n.isRead) {
          _apiService.markNotificationAsRead(n.id);
          return n.copyWith(readAt: DateTime.now());
        }
        return n;
      }).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All notifications marked as read.'),
        backgroundColor: context.colors.card,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<NotificationModel> get _filteredNotifications {
    if (_activeFilter == 'Unread') {
      return _notifications.where((n) => !n.isRead).toList();
    }
    if (_activeFilter == 'Critical') {
      return _notifications.where((n) => n.category == NotificationCategory.incidentAlert).toList();
    }
    return _notifications;
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

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
                    child: Row(
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        if (_unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.badgeRedBg,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '$_unreadCount new',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_unreadCount > 0)
                    IconButton(
                      icon: Icon(Icons.done_all_rounded, color: colors.teal, size: 22),
                      tooltip: 'Mark all as read',
                      onPressed: _markAllAsRead,
                    ),
                ],
              ),
            ),

            // Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: ['All', 'Unread', 'Critical'].map((filter) {
                  final isSelected = _activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (colors.isDark ? const Color(0xFF0B1226) : Colors.white)
                              : colors.text,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: colors.teal,
                      backgroundColor: colors.card,
                      checkmarkColor: Colors.transparent,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? colors.teal : colors.cardBorder,
                          width: 0.8,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _activeFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),

            // Notification Feed List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.teal))
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      color: colors.teal,
                      child: _filteredNotifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_off_outlined, size: 48, color: colors.muted),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No notifications found',
                                    style: TextStyle(fontSize: 14, color: colors.muted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              itemCount: _filteredNotifications.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final n = _filteredNotifications[index];
                                return _buildNotificationCard(colors, n);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 's25'),
    );
  }

  Widget _buildNotificationCard(AppColorScheme colors, NotificationModel n) {
    Color accentColor = colors.teal;
    switch (n.category) {
      case NotificationCategory.incidentAlert:
        accentColor = colors.red;
        break;
      case NotificationCategory.approvalRequest:
        accentColor = colors.warnText;
        break;
      case NotificationCategory.remediationResult:
        accentColor = colors.teal;
        break;
      case NotificationCategory.recoveryResolution:
        accentColor = colors.green;
        break;
      case NotificationCategory.systemNotice:
        accentColor = colors.muted;
        break;
    }

    final isUnread = !n.isRead;

    return InkWell(
      onTap: () => _handleNotificationTap(n),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread ? accentColor.withOpacity(0.5) : colors.cardBorder,
            width: isUnread ? 1.0 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.isDark ? Colors.black.withOpacity(0.3) : const Color.fromRGBO(15, 27, 51, 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(n.category.icon, size: 16, color: accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                            ),
                            if (isUnread) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.cardAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                n.channel.slug,
                                style: TextStyle(fontSize: 10, color: colors.muted, fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: isUnread ? colors.text : colors.muted,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTimeAgo(n.createdAt),
                              style: TextStyle(fontSize: 11, color: colors.muted),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Tap to view',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: accentColor),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
