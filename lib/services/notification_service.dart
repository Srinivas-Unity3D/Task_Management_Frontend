import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import './api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // Add static variable to track unread notifications
  static bool _hasUnreadNotifications = false;

  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int _notificationId = 0;

  NotificationService._internal();

  // Add method to update unread state
  void setUnreadState(bool hasUnread) {
    _hasUnreadNotifications = hasUnread;
  }

  // Add method to get unread state
  bool getUnreadState() {
    return _hasUnreadNotifications;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      print('🔔 [Notification] Initializing notification service...');
      
      // Initialize audio player
      await _audioPlayer.setSource(AssetSource('sounds/notification.mp3'));
      
      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          print('🔔 [Notification] Notification tapped: ${details.payload}');
          // Handle notification tap
          if (details.payload != null) {
            try {
              final data = json.decode(details.payload!);
              // Handle notification data
              print('🔔 [Notification] Notification data: $data');
            } catch (e) {
              print('❌ [Notification] Error parsing notification payload: $e');
            }
          }
        },
      );
      
      _isInitialized = true;
      print('✅ [Notification] Notification service initialized successfully');
    } catch (e) {
      print('❌ [Notification] Error initializing notification service: $e');
      _isInitialized = false;
    }
  }

  Future<List<NotificationModel>> getNotifications() async {
    try {
      print('🔔 [NotificationService] Starting to fetch notifications');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');
      
      print('🔔 [NotificationService] Fetching notifications for user: $userId, username: $username');

      if (userId == null || username == null) {
        print('❌ [NotificationService] User not logged in');
        throw Exception('User not logged in');
      }

      print('🔔 [NotificationService] Making API call to ${ApiService.baseUrl}/tasks/notifications');
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('🔔 [NotificationService] Response status: ${response.statusCode}');
      print('🔔 [NotificationService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          print('✅ [NotificationService] Received ${notifications.length} notifications');
          
          final processedNotifications = notifications.map((json) {
            try {
              // Skip notifications where the current user is the updater
              if ((json['updated_by'] != null && json['updated_by'] == username) ||
                  (json['assigned_by'] != null && json['assigned_by'] == username)) {
                print('ℹ️ [NotificationService] Skipping notification from current user');
                return null;
              }
              
              return NotificationModel(
                id: json['id'] ?? '',
                title: json['title'] ?? '',
                description: json['description'] ?? '',
                senderName: json['sender_name'] ?? '',
                senderRole: json['sender_role'] ?? '',
                createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
                type: _getNotificationType(json['type'] ?? json['priority'] ?? ''),
                isCompleted: json['is_read'] == 1,
              );
            } catch (e) {
              print('❌ [NotificationService] Error parsing notification: $e');
              print('❌ [NotificationService] Problematic JSON: $json');
              return null;
            }
          })
          .where((notification) => notification != null)
          .cast<NotificationModel>()
          .toList();

          print('✅ [NotificationService] Successfully processed ${processedNotifications.length} notifications');
          return processedNotifications;
        } else {
          print('ℹ️ [NotificationService] No notifications found in response');
          return [];
        }
      } else {
        print('❌ [NotificationService] Failed to load notifications. Status: ${response.statusCode}');
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      print('❌ [NotificationService] Error fetching notifications: $e');
      return [];
    }
  }

  String _getTimeAgo(String timestamp) {
    try {
      // Always treat backend timestamp as UTC, then convert to local
      final DateTime utcTime = DateTime.parse(timestamp).toUtc();
      final DateTime localTime = utcTime.toLocal();
      final Duration difference = DateTime.now().difference(localTime);
      
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return '';
    }
  }

  String _getNotificationType(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('task') || lower == 'high' || lower == 'urgent') {
      return 'task';
    } else if (lower.contains('meet')) {
      return 'meeting';
    } else {
      return 'system';
    }
  }

  Future<void> markNotificationAsComplete(String notificationId) async {
    try {
      final response = await _apiService.markNotificationAsComplete(notificationId);
      if (!response['success']) {
        throw Exception(response['message'] ?? 'Failed to mark notification as complete');
      }
    } catch (e) {
      print('❌ [NotificationService] Error marking notification as complete: $e');
      rethrow;
    }
  }

  Future<void> snoozeNotification(String notificationId, DateTime snoozeUntil, {String? reason, Map<String, dynamic>? audioNote}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');

      if (userId == null || username == null) {
        throw Exception('User not logged in');
      }

      // First, get the task ID from the notification
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          final notification = notifications.firstWhere(
            (n) => n['id'] == notificationId,
            orElse: () => throw Exception('Notification not found')
          );

          // Snooze the notification
          final snoozeResponse = await http.post(
            Uri.parse('${ApiService.baseUrl}/notifications/snooze'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'notification_id': notificationId,
              'snooze_until': snoozeUntil.toIso8601String(),
              'reason': reason,
              'audio_note': audioNote,
              'updated_by': username,
            }),
          );

          print('Snooze response status: ${snoozeResponse.statusCode}');
          print('Snooze response body: ${snoozeResponse.body}');

          if (snoozeResponse.statusCode == 200) {
            // Mark the notification as read to clear it from the notification bar
            await markNotificationAsComplete(notificationId);
          } else {
            final errorBody = json.decode(snoozeResponse.body);
            final errorMessage = errorBody['message'] ?? 'Failed to snooze notification';
            throw Exception(errorMessage);
          }
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to fetch notifications');
      }
    } catch (e) {
      print('Error snoozing notification: $e');
      rethrow;
    }
  }

  Future<void> playNotificationSound() async {
    try {
      print('🔔 Playing notification sound...');
      if (!_isInitialized) {
        await initialize();
      }
      
      // Stop any existing playback
      await _audioPlayer.stop();
      
      // Reset the player state
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      
      // Play the sound
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      
      print('🔔 Notification sound played successfully');
    } catch (e) {
      print('🔔 Error playing notification sound: $e');
      // Try to reinitialize and play again
      try {
        _isInitialized = false;
        await initialize();
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      } catch (e) {
        print('🔔 Error during retry: $e');
      }
    }
  }

  Future<void> vibrate() async {
    print('📳 [Notification] Triggering vibration');
    try {
      await HapticFeedback.mediumImpact();
      print('✅ [Notification] Vibration triggered successfully');
    } catch (e) {
      print('❌ [Notification] Error triggering vibration: $e');
    }
  }

  Future<void> handleNewNotification() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Stop any existing playback
      await _audioPlayer.stop();
      
      // Reset the player state
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      
      // Play the sound
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      print('🔔 Error playing notification sound: $e');
      // Try to reinitialize and play again
      try {
        _isInitialized = false;
        await initialize();
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      } catch (e) {
        print('🔔 Error during retry: $e');
      }
    }
  }

  void dispose() {
    try {
      if (_audioPlayer.state != PlayerState.disposed) {
        _audioPlayer.dispose();
      }
      _isInitialized = false;
    } catch (e) {
      print('🔔 Error disposing notification service: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    print('🔔 [Notification] Showing notification: $title');
    try {
      const androidDetails = AndroidNotificationDetails(
        'task_notifications',
        'Task Notifications',
        channelDescription: 'Notifications for task updates and assignments',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF2196F3),
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.mp3',
        ),
      );

      print('🔔 [Notification] Creating notification with ID: ${_notificationId}');
      await _flutterLocalNotificationsPlugin.show(
        _notificationId++,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('✅ [Notification] Notification displayed successfully');
    } catch (e) {
      print('❌ [Notification] Error showing notification: $e');
    }
  }
} 