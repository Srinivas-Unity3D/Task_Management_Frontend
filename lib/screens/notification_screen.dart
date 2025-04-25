import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/socket_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Implement notification fetching from your backend
      // For now, we'll use dummy data
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      setState(() {
        _notifications.addAll([
          {
            'id': '1',
            'title': 'New Task Assigned',
            'message': 'Website Redesign task has been assigned to you',
            'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
            'type': 'task_assigned',
            'isRead': false,
          },
          {
            'id': '2',
            'title': 'Task Updated',
            'message': 'API Integration task deadline has been updated',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
            'type': 'task_updated',
            'isRead': true,
          },
        ]);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final IconData icon;
    final Color iconColor;
    
    switch (notification['type']) {
      case 'task_assigned':
        icon = Icons.assignment;
        iconColor = AppColors.accentCyan;
        break;
      case 'task_updated':
        icon = Icons.edit;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: notification['isRead'] 
            ? null 
            : Border.all(color: AppColors.accentCyan, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['message'],
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getTimeAgo(notification['timestamp']),
                  style: TextStyle(
                    color: AppColors.textGrey.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.accentCyan),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  for (var notification in _notifications) {
                    notification['isRead'] = true;
                  }
                });
              },
              child: const Text(
                'Mark all as read',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: AppColors.textGrey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          color: AppColors.textGrey.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.accentCyan,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) => _buildNotificationItem(
                      _notifications[index],
                    ),
                  ),
                ),
    );
  }
} 