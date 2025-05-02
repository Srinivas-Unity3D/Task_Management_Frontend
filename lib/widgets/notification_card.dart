import 'package:flutter/material.dart';
import '../models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onSnooze;
  final VoidCallback onMarkComplete;

  const NotificationCard({
    Key? key,
    required this.notification,
    required this.onSnooze,
    required this.onMarkComplete,
  }) : super(key: key);

  Color _getIndicatorColor(String type) {
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                  color: _getIndicatorColor(notification.type),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                notification.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
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
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
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
                      color: Color(0xFF00E5FF),
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
                onPressed: onSnooze,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  'Snooze',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: onMarkComplete,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 32),
                  backgroundColor: const Color(0xFF00E5FF).withOpacity(0.1),
                ),
                child: const Text(
                  'Mark as Read',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 