import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/socket_service.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'type': 'New Task Assignment',
      'description': 'Project Alpha needs review',
      'time': DateTime.now().subtract(const Duration(minutes: 10)),
      'user': 'Durga',
      'role': 'Product Manager',
      'status': 'pending'
    },
    {
      'type': 'Meeting Reminder',
      'description': 'Team standup at 2 PM',
      'time': DateTime.now().subtract(const Duration(hours: 1)),
      'user': 'Azim',
      'role': 'Admin',
      'status': 'pending'
    },
    {
      'type': 'System Update',
      'description': 'New features available',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'user': 'Ayan',
      'role': 'Developer',
      'status': 'pending'
    },
  ];

  final _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _socketService.listenToTaskNotifications(_handleNewNotification);
  }

  @override
  void dispose() {
    _socketService.removeTaskNotificationListener(_handleNewNotification);
    super.dispose();
  }

  void _handleNewNotification(dynamic data) {
    if (mounted) {
      setState(() {
        _notifications.insert(0, data);
      });
    }
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'New Task Assignment':
        return Colors.red;
      case 'Meeting Reminder':
        return Colors.orange;
      case 'System Update':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getTypeColor(notification['type']),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  notification['type'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _getTimeAgo(notification['time']),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              notification['description'],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white24,
                  child: Text(
                    notification['user'][0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  notification['user'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  notification['role'],
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    // TODO: Implement snooze functionality
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: const Text('Snooze'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // TODO: Implement mark as complete functionality
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF7DF9FF),
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                  child: const Text('Mark as Complete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF7DF9FF),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Text(
                'No new notifications',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) => _buildNotificationCard(_notifications[index]),
            ),
    );
  }
} 