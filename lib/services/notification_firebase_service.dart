import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskmanagement/services/api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:taskmanagement/services/notification_service.dart';

//import '../screens/notification_screen.dart';
import '../screens/notifications_screen.dart'; // Adjust path to your NotificationScreen
import '../screens/alarm_screen.dart'; // Adjust path to your AlarmScreen

/// A singleton service for managing Firebase Cloud Messaging (FCM) push notifications.
/// Handles permission requests, foreground/background/terminated notifications,
/// and local notification display with navigation.
@pragma('vm:entry-point')
class NotificationFirebaseService {
  // Singleton instance
  static final NotificationFirebaseService _instance = NotificationFirebaseService._internal();
  factory NotificationFirebaseService() => _instance;
  NotificationFirebaseService._internal();

  // Dependencies
  late FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Flag to prevent multiple permission requests
  bool _permissionRequested = false;

  /// Initializes the notification service, setting up permissions, local notifications,
  /// and listeners for all notification scenarios.
  Future<void> initialize() async {
    try {
      print('🔄 Initializing NotificationFirebaseService...');
      
      // Initialize Firebase Messaging
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );
      print('📱 Notification permission status: ${settings.authorizationStatus}');
      
      // Get FCM token
      String? token = await _messaging.getToken();
      print('🔑 FCM Token: $token');
      
      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'task_alarms',
        'Task Alarms',
        description: 'High priority notifications for task alarms',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
      );
      
      // Create the Android notification channel
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      print('✅ Notification channel created successfully');
      
      // Initialize local notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) {
            final data = jsonDecode(payload);
            if (response.actionId == 'snooze') {
              stopAlarm();
              Get.to(() => const AlarmScreen(), arguments: {
                'task_id': data['task_id'],
                'alarm_id': data['alarm_id'],
                'title': data['title'],
                'show_snooze': true,
              });
            } else if (response.actionId == 'dismiss') {
              stopAlarm();
            } else {
              _handleNotificationTap(payload);
            }
          }
        },
      );
      
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📱 Received foreground message: ${message.messageId}');
        _handleMessage(message);
      });
      
      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 Notification tapped: ${message.messageId}');
        _handleMessage(message);
      });
      
      print('✅ NotificationFirebaseService initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotificationFirebaseService: $e');
    }
  }

  /// Requests notification permissions with a user-friendly prompt.
  Future<void> _requestNotificationPermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        criticalAlert: false,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted.');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ Provisional permission granted.');
      } else {
        debugPrint('❌ Notification permission denied.');
        Get.snackbar(
          'Notification Permission',
          'Please enable notifications to receive updates.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
          onTap: (_) => AppSettings.openAppSettings(type: AppSettingsType.notification),
        );
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
  }

  /// Retrieves the FCM device token for targeting notifications.
  Future<String?> getDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('📱 FCM Token: ${token?.substring(0, 20)}...');
      
      // When token is refreshed, update on backend
      // This will also be handled by the ApiService token refresh listener
      _updateFcmTokenOnBackend(token);
      
      return token;
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
      return null;
    }
  }
  
  /// Send FCM token to backend to enable push notifications
  Future<void> _updateFcmTokenOnBackend(String? token) async {
    if (token == null) return;
    
    try {
      final prefs = await Get.find<SharedPreferences>();
      final username = prefs.getString('username');
      
      if (username == null) {
        debugPrint('⚠️ Cannot update FCM token on backend: No logged in user');
        return;
      }
      
      debugPrint('🔄 Updating FCM token on backend for user: $username');
      
      // Call API service to update token in backend
      // This is also handled by ApiService.setupFcmTokenRefreshListener
      // but we also do it here to ensure the token is set during initialization
      
      // Implement direct API call if needed
    } catch (e) {
      debugPrint('❌ Error updating FCM token on backend: $e');
    }
  }

  /// Handles incoming messages from Firebase Cloud Messaging.
  Future<void> _handleMessage(RemoteMessage message) async {
    try {
      print('📱 Handling message: [32m${message.messageId}[0m');
      print('📱 Message data: ${message.data}');
      print('📱 Notification: ${message.notification?.title} - ${message.notification?.body}');

      // Check if this is an alarm notification
      final bool isAlarm = message.data['type'] == 'task_alarm' || 
                          (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));

      if (isAlarm) {
        // Show alarm notification
        await _showAlarmNotification(message);
        // Trigger alarm sound and vibration
        await _triggerAlarm(message.data);
        // Show foreground alarm screen
        print('🚨 Attempting to navigate to AlarmScreen in foreground');
        try {
          Get.to(() => AlarmScreen(
            taskId: message.data['task_id'],
            alarmId: message.data['alarm_id'],
            taskTitle: message.data['title'],
            assigneeName: message.data['assignee_name'],
            assignedBy: message.data['assigned_by'],
            dueDate: message.data['deadline'],
          ));
        } catch (e) {
          print('❌ Get.to() navigation failed, trying global navigator key: $e');
          try {
            globalNavigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => AlarmScreen(
                  taskId: message.data['task_id'],
                  alarmId: message.data['alarm_id'],
                  taskTitle: message.data['title'],
                  assigneeName: message.data['assignee_name'],
                  assignedBy: message.data['assigned_by'],
                  dueDate: message.data['deadline'],
                ),
                fullscreenDialog: true,
              ),
            );
          } catch (e2) {
            print('❌ Global navigator key navigation also failed: $e2');
          }
        }
      } else {
        // Show regular notification without alarm sound
        await _showLocalNotification(message);
        // Only navigate to notification screen for non-alarm notifications
        _handleNotificationTap(jsonEncode(message.data));
      }
    } catch (e) {
      print('❌ Error handling message: $e');
    }
  }

  /// Displays a local notification for the given FCM message.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    try {
      const channelId = 'task_alarms';
      const channel = AndroidNotificationChannel(
        channelId,
        'Task Alarms',
        description: 'Used for important notifications',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        enableLights: true,
      );

      // Create notification channel for Android
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        color: const Color(0xFF2196F3),
        ledColor: const Color(0xFF2196F3),
        ledOnMs: 1000,
        ledOffMs: 500,
        actions: [
          const AndroidNotificationAction('stop', 'Stop Alarm'),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarm.mp3',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      print('❌ Failed to show local notification: $e');
    }
  }

  /// Shows an alarm notification
  Future<void> _showAlarmNotification(RemoteMessage message) async {
    try {
      const channelId = 'task_alarms';
      const channel = AndroidNotificationChannel(
        channelId,
        'Task Alarms',
        description: 'High priority notifications for task alarms',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
      );

      // Create notification channel for Android
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Get task details from message data
      final taskTitle = message.data['title'] ?? 'Task Alarm';
      final assignedBy = message.data['assigned_by'] ?? 'Unknown';
      final deadline = message.data['deadline'] ?? '';
      final taskId = message.data['task_id'] ?? '';
      final alarmId = message.data['alarm_id'] ?? '';

      // Create notification content
      final notificationContent = '''
Task: $taskTitle
Assigned by: $assignedBy
Deadline: $deadline
''';

      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('alarm'),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: const Color(0xFF2196F3),
        ledColor: const Color(0xFF2196F3),
        ledOnMs: 1000,
        ledOffMs: 500,
        actions: [
          const AndroidNotificationAction(
            'snooze',
            'Snooze',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            'dismiss',
            'Dismiss',
            cancelNotification: true,
          ),
        ],
        styleInformation: BigTextStyleInformation(
          notificationContent,
          htmlFormatBigText: true,
          contentTitle: 'Task Alarm',
          htmlFormatContentTitle: true,
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarm.mp3',
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: 'TASK_ALARM',
        threadIdentifier: 'task_alarms',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotificationsPlugin.show(
        message.hashCode,
        'Task Alarm',
        notificationContent,
        notificationDetails,
        payload: jsonEncode({
          ...message.data,
          'action': 'task_alarm',
        }),
      );
    } catch (e) {
      print('❌ Failed to show alarm notification: $e');
    }
  }

  /// Handles notification taps, navigating to the appropriate screen based on payload.
  void _handleNotificationTap(String? payload) {
    try {
      if (payload == null) {
        Get.to(() => const NotificationScreen());
        return;
      }

      final data = jsonDecode(payload);
      
      // Don't handle taps for alarm notifications here
      if (data['type'] == 'task_alarm' || (data.containsKey('task_id') && data.containsKey('alarm_id'))) {
        return;
      }
      
      // Handle notification actions
      switch (data['action']) {
        case 'dismiss':
          stopAlarm();
          return;
        case 'snooze':
          stopAlarm();
          // Navigate to alarm screen with task details
          Get.to(() => AlarmScreen(
            taskId: data['task_id'],
            alarmId: data['alarm_id'],
            taskTitle: data['title'],
            assigneeName: data['assignee_name'],
            assignedBy: data['assigned_by'],
            dueDate: data['deadline'],
            showSnooze: true,
          ));
          return;
        default:
          Get.to(() => const NotificationScreen());
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
      Get.to(() => const NotificationScreen());
    }
  }

  /// Background message handler (top-level function required by FCM).
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    try {
      await Firebase.initializeApp();
      print('📱 Handling background message: ${message.messageId}');
      print('📱 Message data: ${message.data}');
      
      // Initialize notifications plugin
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      
      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'task_alarms',
        'Task Alarms',
        description: 'High priority notifications for task alarms',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
      );
      
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      // Check if this is an alarm notification
      final bool isAlarm = message.data['type'] == 'task_alarm' || 
                          (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
      
      if (isAlarm) {
        // Get task details from message data
        final taskTitle = message.data['title'] ?? 'Task Alarm';
        final assignedBy = message.data['assigned_by'] ?? 'Unknown';
        final deadline = message.data['deadline'] ?? '';
        final taskId = message.data['task_id'] ?? '';
        final alarmId = message.data['alarm_id'] ?? '';

        // Create notification content
        final notificationContent = '''
Task: $taskTitle
Assigned by: $assignedBy
Deadline: $deadline
''';

        // Show high priority notification
        final androidDetails = AndroidNotificationDetails(
          'task_alarms',
          'Task Alarms',
          channelDescription: 'High priority notifications for task alarms',
          importance: Importance.max,
          priority: Priority.high,
          sound: const RawResourceAndroidNotificationSound('alarm'),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          color: const Color(0xFF2196F3),
          ledColor: const Color(0xFF2196F3),
          ledOnMs: 1000,
          ledOffMs: 500,
          actions: [
            const AndroidNotificationAction(
              'snooze',
              'Snooze',
              showsUserInterface: true,
              cancelNotification: false,
            ),
            const AndroidNotificationAction(
              'dismiss',
              'Dismiss',
              cancelNotification: true,
            ),
          ],
          styleInformation: BigTextStyleInformation(
            notificationContent,
            htmlFormatBigText: true,
            contentTitle: 'Task Alarm',
            htmlFormatContentTitle: true,
          ),
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'alarm.mp3',
          interruptionLevel: InterruptionLevel.timeSensitive,
          categoryIdentifier: 'TASK_ALARM',
          threadIdentifier: 'task_alarms',
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        // Show the notification
        await flutterLocalNotificationsPlugin.show(
          message.hashCode,
          'Task Alarm',
          notificationContent,
          notificationDetails,
          payload: jsonEncode({
            ...message.data,
            'action': 'task_alarm',
          }),
        );
        
        // Play alarm sound
        final audioPlayer = AudioPlayer();
        await audioPlayer.setReleaseMode(ReleaseMode.loop);
        await audioPlayer.setVolume(1.0);
        await audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
        await audioPlayer.resume();
        
        // Vibrate
        HapticFeedback.heavyImpact();

        // Handle notification actions
        flutterLocalNotificationsPlugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            final data = jsonDecode(response.payload ?? '{}');
            switch (data['action']) {
              case 'dismiss':
                audioPlayer.stop();
                break;
              case 'snooze':
                audioPlayer.stop();
                // The app will be opened by the system due to showsUserInterface: true
                break;
            }
          },
        );
      } else {
        // Show regular notification without alarm sound
        final androidDetails = AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await flutterLocalNotificationsPlugin.show(
          message.hashCode,
          message.notification?.title ?? 'New Notification',
          message.notification?.body ?? '',
          notificationDetails,
          payload: jsonEncode(message.data),
        );
      }
      
      print('✅ Background notification shown successfully');
    } catch (e) {
      print('❌ Error handling background message: $e');
    }
  }

  /// Triggers the alarm with sound and vibration
  Future<void> _triggerAlarm(Map<String, dynamic> data) async {
    try {
      print('🔔 Triggering alarm...');
      
      // Initialize audio player
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
      await _audioPlayer.resume();
      
      // Start vibration
      HapticFeedback.heavyImpact();
      
      print('✅ Alarm triggered successfully');
    } catch (e) {
      print('❌ Error triggering alarm: $e');
    }
  }

  /// Stops the alarm
  Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
      print('✅ Alarm stopped successfully');
    } catch (e) {
      print('❌ Error stopping alarm: $e');
    }
  }

  /// Disposes the audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}