import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import './api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import '../screens/alarm_screen.dart';
import '../services/alarm_service.dart';

// Add a global navigator key (in main.dart, but reference here)
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // Add static variable to track unread notifications
  static bool _hasUnreadNotifications = false;

  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int _notificationId = 0;
  Function(Map<String, dynamic>)? onAlarmTriggered;

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
      // Initialize audio player
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          if (response.payload != null) {
            _handleNotificationTap(response);
          }
        },
      );

      // Create notification channel for alarms
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'task_alarms',
        'Task Alarms',
        description: 'Notifications for task alarms',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Register the alarm triggered callback
      AlarmService.setOnAlarmTriggeredCallback(_showAlarmUI);

      _isInitialized = true;
    } catch (e) {
      print('🔔 Error initializing notification service: $e');
    }
  }

  // Shared method to show snooze UI - can be used by notification bar or alarm screen
  Future<void> showSnoozeUI({
    required BuildContext context,
    required String taskId,
    required String alarmId,
    required String taskTitle,
    Function? onSnoozeComplete,
  }) async {
    // Default snooze times
    final List<int> snoozeOptions = [5, 15, 30, 60];
    int selectedSnoozeMinutes = snoozeOptions[0];
    
    // Show the snooze dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Snooze Alarm'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Snooze "$taskTitle" for:'),
                  SizedBox(height: 20),
                  DropdownButton<int>(
                    value: selectedSnoozeMinutes,
                    isExpanded: true,
                    items: snoozeOptions.map((int minutes) {
                      return DropdownMenuItem<int>(
                        value: minutes,
                        child: Text('$minutes minutes'),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      if (value != null) {
                        setState(() {
                          selectedSnoozeMinutes = value;
                        });
                      }
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, 'cancel');
              },
              child: Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context, 'snooze');
                
                // Calculate snooze time
                final DateTime snoozeUntil = DateTime.now().add(Duration(minutes: selectedSnoozeMinutes));
                
                try {
                  // Show loading indicator
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Snoozing alarm for $selectedSnoozeMinutes minutes...'))
                  );
                  
                  final response = await http.post(
                    Uri.parse('${ApiService.baseUrl}/tasks/$taskId/snooze_alarm'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                    },
                    body: json.encode({
                      'alarm_id': alarmId,
                      'snooze_until': snoozeUntil.toIso8601String(),
                    }),
                  );
                  
                  if (response.statusCode == 200) {
                    print('✅ Alarm snoozed successfully');
                    if (onSnoozeComplete != null) {
                      onSnoozeComplete();
                    }
                  } else {
                    print('❌ Failed to snooze alarm: ${response.statusCode}');
                    print('❌ Error response: ${response.body}');
                    
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Failed to snooze alarm'))
                    );
                  }
                } catch (e) {
                  print('❌ Error snoozing alarm: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to snooze alarm'))
                  );
                }
              },
              child: Text('SNOOZE'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAlarmNotification(Map<String, dynamic> alarmData) async {
    try {
      print('🔔 Handling alarm notification: $alarmData');
      
      // Show local notification with full screen intent
      await showAlarmNotification(
        title: 'Task Alarm',
        body: 'Time to check your task: ${alarmData['task_title']}',
        alarmData: alarmData,
      );

      // Play alarm sound
      await playAlarmSound();

      // Trigger alarm callback to show alarm screen
      if (onAlarmTriggered != null) {
        print('🔔 Triggering alarm callback');
        onAlarmTriggered!(alarmData);
      }

      // Show the AlarmScreen as a dialog if in foreground
      if (globalNavigatorKey.currentState != null) {
        globalNavigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => AlarmScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      print('🔔 Error handling alarm notification: $e');
    }
  }

  Future<void> _handleNotificationTap(dynamic response) async {
    try {
      Map<String, dynamic> data;
      if (response is NotificationResponse && response.payload != null) {
        data = json.decode(response.payload!);
        if (data['type'] == 'alarm' && onAlarmTriggered != null) {
          onAlarmTriggered!(data);
        }
      }
    } catch (e) {
      print('🔔 Error handling notification tap: $e');
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

  Future<void> playAlarmSound() async {
    try {
      print('🔔 Playing alarm sound...');
      if (!_isInitialized) {
        await initialize();
      }
      
      // Stop any existing playback
      await _audioPlayer.stop();
      
      // Reset the player state
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      
      // Play the alarm sound
      print('🔔 Setting alarm sound source');
      await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
      print('🔔 Playing alarm sound');
      await _audioPlayer.resume();
      
      print('🔔 Alarm sound played successfully');
    } catch (e) {
      print('🔔 Error playing alarm sound: $e');
      // Try to reinitialize and play again
      try {
        _isInitialized = false;
        await initialize();
        await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
        await _audioPlayer.resume();
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
        'task_channel',
        'Task Notifications',
        channelDescription: 'Notifications for task updates',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('notification'),
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'notification.mp3',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      print('🔔 [Notification] Creating notification with ID: ${_notificationId}');
      await _flutterLocalNotificationsPlugin.show(
        _notificationId++,
        title,
        body,
        details,
        payload: payload,
      );
      print('✅ [Notification] Notification displayed successfully');
    } catch (e) {
      print('❌ [Notification] Error showing notification: $e');
    }
  }

  Future<void> showAlarmNotification({
    required String title,
    required String body,
    required Map<String, dynamic> alarmData,
  }) async {
    print('🔔 Showing alarm notification');
    try {
      // Show notification with full screen intent
      const androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        'Alarm Notifications',
        channelDescription: 'Notifications for task alarms',
        importance: Importance.max,
        priority: Priority.max,
        sound: RawResourceAndroidNotificationSound('alarm'),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFFE53935),
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'alarm.mp3',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      print('🔔 Creating alarm notification');
      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch,
        title,
        body,
        details,
        payload: json.encode(alarmData),
      );

      print('🔔 Alarm notification shown successfully');
    } catch (e) {
      print('🔔 Error showing alarm notification: $e');
    }
  }

  // Callback to show the alarm UI
  Future<void> _showAlarmUI(Map<String, dynamic> alarmData) async {
    try {
      print('🔔 Showing alarm UI for: ${alarmData['title']}');
      
      // Use the global navigator key to show the alarm screen
      if (globalNavigatorKey.currentState != null) {
        await globalNavigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => AlarmScreen(
              taskId: alarmData['task_id'] ?? '',
              taskTitle: alarmData['title'] ?? 'Task Alarm',
              alarmId: alarmData['alarm_id'] ?? '',
              assigneeName: alarmData['assignee_name'] ?? '',
              dueDate: alarmData['due_date'] ?? '',
            ),
            fullscreenDialog: true,
          ),
        );
      } else {
        print('❌ Global navigator key is null, cannot show alarm screen');
      }
    } catch (e) {
      print('❌ Error showing alarm UI: $e');
    }
  }
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  if (message.data['type'] == 'alarm') {
    await notificationService._handleAlarmNotification(message.data);
  }
} 