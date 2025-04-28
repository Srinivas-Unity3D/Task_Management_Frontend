import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await _notificationService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  void _handleSnooze(String notificationId) {
    // TODO: Implement snooze functionality
    print('Snoozing notification: $notificationId');
  }

  Future<void> _handleMarkComplete(String notificationId) async {
    try {
      await _notificationService.markAsComplete(notificationId);
      await _loadNotifications(); // Refresh the list
    } catch (e) {
      print('Error marking notification as complete: $e');
    }
  }

  Color _getDotColor(String type) {
    switch (type.toLowerCase()) {
      case 'task':
        return Colors.red;
      case 'meeting':
        return Colors.yellow;
      case 'system':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1C2B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _notifications.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2746),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getDotColor(notification.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notification.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            notification.timeAgo,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white24,
                            child: Text(
                              notification.senderName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.senderName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                notification.senderRole,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _handleSnooze(notification.id),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white.withOpacity(0.7),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: const Text('Snooze'),
                          ),
                          TextButton(
                            onPressed: () => _handleMarkComplete(notification.id),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF).withOpacity(0.1),
                              foregroundColor: const Color(0xFF00E5FF),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: const Text('Mark as Complete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
} 