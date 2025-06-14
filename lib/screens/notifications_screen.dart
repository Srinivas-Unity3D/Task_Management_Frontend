import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_firebase_service.dart';
import '../services/notification_service.dart';
import '../widgets/snooze_dialog.dart';
import '../widgets/notification_card.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationFirebaseService _notificationService = NotificationFirebaseService();
  List<NotificationModel> _notifications = [];
  List<NotificationModel> _unreadNotifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    // Check if all notifications are read when leaving the screen
    _checkAndUpdateBadgeState();
    super.dispose();
  }

  Future<void> _checkAndUpdateBadgeState() async {
    try {
      // Get fresh notifications from the server
      final notifications = await _notificationService.getNotifications();
      final hasUnread = notifications.any((n) => !n.isCompleted);
      print('🔔 [Notifications] Checking unread state before leaving: hasUnread=$hasUnread');
      _notificationService.setUnreadState(hasUnread);
    } catch (e) {
      print('❌ [Notifications] Error checking unread state: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      print('🔔 [NotificationScreen] Starting to load notifications');
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final notifications = await _notificationService.getNotifications();
      print('🔔 [NotificationScreen] Received ${notifications.length} notifications');
      
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _unreadNotifications = notifications.where((n) => !n.isCompleted).toList();
          _isLoading = false;
          print('🔔 [NotificationScreen] Updated state with ${_notifications.length} total notifications and ${_unreadNotifications.length} unread notifications');
        });
      }
    } catch (e) {
      print('❌ [NotificationScreen] Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSnooze(String notificationId) async {
    showDialog(
      context: context,
      builder: (context) => SnoozeDialog(
        notificationId: notificationId,
        onSnoozeComplete: () async {
          await _loadNotifications();
        },
      ),
    );
  }

  Future<void> _handleMarkComplete(String notificationId) async {
    try {
      print('🔔 [Notifications] Marking notification as complete: $notificationId');
      await _notificationService.markNotificationAsComplete(notificationId);
      
      // Update the notification in the list
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notificationId) {
            return NotificationModel(
              id: n.id,
              title: n.title,
              description: n.description,
              senderName: n.senderName,
              senderRole: n.senderRole,
              createdAt: n.createdAt,
              type: n.type,
              isCompleted: true,
            );
          }
          return n;
        }).toList();
        _unreadNotifications.removeWhere((n) => n.id == notificationId);
      });
      
      // Check if all notifications are now read
      final hasUnread = _notifications.any((n) => !n.isCompleted);
      print('🔔 [Notifications] After marking complete: hasUnread=$hasUnread');
      _notificationService.setUnreadState(hasUnread);
    } catch (e) {
      print('❌ [Notifications] Error marking notification as complete: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark notification as complete'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      print('🔔 [Notifications] Marking all notifications as read...');
      final notifications = await _notificationService.getNotifications();
      for (var notification in notifications) {
        if (!notification.isCompleted) {
          // await _notificationService.markNotificationAsComplete(notification.id);
        }
      }
      
      // Clear the badge state since all notifications are marked as read
      // _notificationService.setUnreadState(false);
      
      if (mounted) {
        setState(() {
          _unreadNotifications = [];
          _notifications = _notifications.map((n) => NotificationModel(
            id: n.id,
            title: n.title,
            description: n.description,
            senderName: n.senderName,
            senderRole: n.senderRole,
            createdAt: n.createdAt,
            type: n.type,
            isCompleted: true,
          )).toList();
        });
      }
    } catch (e) {
      print('❌ [Notifications] Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark all notifications as read'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return WillPopScope(
      onWillPop: () async {
        await _checkAndUpdateBadgeState();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1C2B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF00E5FF),
            ),
            onPressed: () async {
              await _checkAndUpdateBadgeState();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
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
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadNotifications,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Notifications Yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You\'ll be notified when you receive new tasks,\nmeetings, or system updates.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _unreadNotifications.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          print('Notification list builder called for index: $index');
                          final notification = _unreadNotifications[index];
                          return NotificationCard(
                            notification: notification,
                            onSnooze: () => _handleSnooze(notification.id),
                            onMarkComplete: () => _handleMarkComplete(notification.id),
                          );
                        },
                      ),
      ),
    );
  }
} 