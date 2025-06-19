// import 'dart:convert';
// import 'dart:io';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:get/get.dart';
// import 'package:app_settings/app_settings.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
// import 'package:permission_handler/permission_handler.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest.dart' as tz;
// import '../screens/notifications_screen.dart';
// import './api_service.dart';
// import '../models/notification_model.dart';
// import './alarm_service.dart';
//
// @pragma('vm:entry-point')
// class NotificationFirebaseService {
//   final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
//   final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   bool _permissionRequested = false;
//   final ApiService _apiService = ApiService();
//   static bool _hasUnreadNotifications = false;
//   final AlarmService _alarmService = AlarmService();
//   static const String _alarmsKey = 'pending_alarms';
//
//   static final NotificationFirebaseService _instance = NotificationFirebaseService._internal();
//   factory NotificationFirebaseService() => _instance;
//   NotificationFirebaseService._internal() {
//     initialize();
//     print('[Flutter] Initialized NotificationFirebaseService at ${DateTime.now()}');
//   }
//
//   // @pragma('vm:entry-point')
//   // static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   //   try {
//   //     debugPrint('📩 Background Notification: ${message.data['title'] ?? 'No title'}');
//   //     debugPrint('Message data: ${jsonEncode(message.data)}');
//   //     await Firebase.initializeApp();
//   //     tz.initializeTimeZones();
//   //     tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
//   //     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//   //     const iosSettings = DarwinInitializationSettings();
//   //     const initializationSettings = InitializationSettings(
//   //       android: androidSettings,
//   //       iOS: iosSettings,
//   //     );
//   //     await FlutterLocalNotificationsPlugin().initialize(initializationSettings);
//   //     const androidChannel = AndroidNotificationChannel(
//   //       'task_alarms',
//   //       'Task Alarms',
//   //       description: 'High priority notifications for task alarms',
//   //       importance: Importance.max,
//   //       playSound: true,
//   //       enableLights: true,
//   //       enableVibration: true,
//   //       showBadge: true,
//   //       audioAttributesUsage: AudioAttributesUsage.alarm,
//   //     );
//   //     final androidPlugin = FlutterLocalNotificationsPlugin()
//   //         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
//   //     await androidPlugin?.createNotificationChannel(androidChannel);
//   //     await AlarmService().initialize();
//   //     await showLocalNotification(message.data);
//   //   } catch (e, stackTrace) {
//   //     debugPrint('❌ Error in background handler: $e\n$stackTrace');
//   //   }
//   // }
//
//
//   @pragma('vm:entry-point')
//   static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//     try {
//       debugPrint('📩 Background Notification START: ${message.data['title'] ?? 'No title'}');
//       debugPrint('Message data: ${jsonEncode(message.data)}');
//       await Firebase.initializeApp();
//       debugPrint('Firebase initialized');
//       tz.initializeTimeZones();
//       tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
//       debugPrint('Timezone initialized');
//       final localNotifications = FlutterLocalNotificationsPlugin();
//       const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//       const iosSettings = DarwinInitializationSettings();
//       const initializationSettings = InitializationSettings(
//         android: androidSettings,
//         iOS: iosSettings,
//       );
//       await localNotifications.initialize(initializationSettings);
//       debugPrint('Local notifications initialized');
//       const androidChannel = AndroidNotificationChannel(
//         'task_alarms',
//         'Task Alarms',
//         description: 'High priority notifications for task alarms',
//         importance: Importance.max,
//         playSound: true,
//         enableLights: true,
//         enableVibration: true,
//         showBadge: true
//       );
//       final androidPlugin = localNotifications
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
//       await androidPlugin?.createNotificationChannel(androidChannel);
//       debugPrint('Notification channel created');
//       final alarmService = AlarmService();
//       await alarmService.initialize();
//       debugPrint('AlarmService initialized');
//       await showLocalNotification(message.data);
//       debugPrint('📩 Background Notification END: ${message.data['title'] ?? 'No title'}');
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error in background handler: $e\n$stackTrace');
//     } finally {
//       // Ensure resources are closed
//       try {
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.commit();
//         debugPrint('SharedPreferences committed');
//       } catch (e) {
//         debugPrint('❌ Error committing SharedPreferences: $e');
//       }
//     }
//   }
//
//   Future<void> initialize() async {
//     try {
//       print('[Flutter] Initializing NotificationFirebaseService...');
//       await _alarmService.initialize();
//       await _initializeLocalNotifications();
//       _setupTokenRefreshListener();
//       await _configureFcmListeners();
//       await _restoreAlarms();
//       print('[Flutter] NotificationFirebaseService initialized successfully');
//     } catch (e, stackTrace) {
//       debugPrint('❌ Notification initialization failed: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> requestNotificationPermission() async {
//     if (_permissionRequested) return;
//     _permissionRequested = true;
//     try {
//       final settings = await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//         announcement: false,
//         criticalAlert: false,
//         provisional: false,
//       );
//       if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//         debugPrint('✅ Notification permission granted.');
//       } else {
//         debugPrint('❌ Notification permission denied.');
//         Get.snackbar(
//           'Notification Permission',
//           'Please enable notifications to receive updates.',
//           snackPosition: SnackPosition.BOTTOM,
//           duration: const Duration(seconds: 4),
//           onTap: (_) => AppSettings.openAppSettings(type: AppSettingsType.notification),
//         );
//       }
//       if (Platform.isAndroid) {
//         final status = await Permission.scheduleExactAlarm.status;
//         if (!status.isGranted) {
//           await Permission.scheduleExactAlarm.request();
//         }
//         final notificationStatus = await Permission.notification.status;
//         if (!notificationStatus.isGranted) {
//           await Permission.notification.request();
//         }
//         final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
//         if (!batteryStatus.isGranted) {
//           Get.snackbar(
//             'Battery Optimization',
//             'Disable battery optimization for reliable alarms.',
//             snackPosition: SnackPosition.BOTTOM,
//             duration: const Duration(seconds: 6),
//             onTap: (_) => AppSettings.openAppSettings(type: AppSettingsType.settings),
//           );
//           await Permission.ignoreBatteryOptimizations.request();
//           // Recheck after request
//           if (!(await Permission.ignoreBatteryOptimizations.status).isGranted) {
//             debugPrint('❌ Battery optimization still enabled.');
//           }
//         } else {
//           debugPrint('✅ Battery optimization disabled.');
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ Error requesting permissions: $e');
//     }
//   }
//
//
//
//   Future<String?> getDeviceToken() async {
//     try {
//       final token = await _messaging.getToken();
//       debugPrint('📱 FCM Token: $token');
//       return token;
//     } catch (e) {
//       debugPrint('❌ Failed to get FCM token: $e');
//       return null;
//     }
//   }
//
//   Future<void> _initializeLocalNotifications() async {
//     print('[Flutter] Starting local notifications initialization');
//     const androidChannel = AndroidNotificationChannel(
//       'task_alarms',
//       'Task Alarms',
//       description: 'High priority notifications for task alarms',
//       importance: Importance.max,
//       playSound: true,
//       enableLights: true,
//       enableVibration: true,
//       showBadge: true,
//       audioAttributesUsage: AudioAttributesUsage.alarm,
//     );
//     final androidPlugin = _localNotificationsPlugin
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
//     try {
//       print('[Flutter] Creating notification channel');
//       await androidPlugin?.createNotificationChannel(androidChannel);
//       print('[Flutter] Notification channel created successfully');
//     } catch (e, stackTrace) {
//       print('[Flutter] Error creating notification channel: $e\n$stackTrace');
//     }
//     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: false,
//       requestBadgePermission: false,
//       requestSoundPermission: false,
//     );
//     const initializationSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );
//     try {
//       print('[Flutter] Initializing FlutterLocalNotificationsPlugin');
//       await _localNotificationsPlugin.initialize(
//         initializationSettings,
//         onDidReceiveNotificationResponse: (NotificationResponse response) async {
//           print('[Flutter] Notification response received: '
//               'actionId=${response.actionId}, payload=${response.payload}, '
//               'input=${response.input}');
//           try {
//             if (response.payload != null) {
//               _handleNotificationTap(response.payload!);
//             }
//           } catch (e, stackTrace) {
//             print('[Flutter] Error handling notification response: $e\n$stackTrace');
//           }
//         },
//       );
//       print('[Flutter] Local notifications initialized successfully');
//     } catch (e, stackTrace) {
//       print('[Flutter] Error initializing local notifications: $e\n$stackTrace');
//     }
//   }
//
//   void _setupTokenRefreshListener() {
//     _messaging.onTokenRefresh.listen((newToken) async {
//       debugPrint('🔄 New FCM Token: $newToken');
//       final prefs = await SharedPreferences.getInstance();
//       final currentUser = prefs.getString('username');
//       if (currentUser != null) {
//         await _apiService.updateFcmToken(currentUser, newToken);
//       }
//     }).onError((e) {
//       debugPrint('❌ Error on token refresh: $e');
//     });
//   }
//
//   Future<void> _configureFcmListeners() async {
//     try {
//       FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//         debugPrint('📩 Foreground Notification: ${message.data['title'] ?? 'No title'}');
//         debugPrint('Message data: ${jsonEncode(message.data)}');
//         showLocalNotification(message.data);
//       });
//       FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//         print('📱 Handling background message tap: ${message.messageId}');
//         print('📱 Message data: ${message.data}');
//         _handleNotificationTap(jsonEncode(message.data));
//       });
//       final initialMessage = await _messaging.getInitialMessage();
//       if (initialMessage != null) {
//         print('📱 Handling initial message: ${initialMessage.messageId}');
//         _handleNotificationTap(jsonEncode(initialMessage.data));
//       }
//       FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error configuring FCM listeners: $e\n$stackTrace');
//     }
//   }
//
//   static Future<void> showLocalNotification(Map<String, dynamic> data) async {
//     try {
//       final type = data['type'];
//       if (type != 'task_created' && type != 'set_alarm') {
//         print('Skipping notification for type: $type');
//         return;
//       }
//
//       final taskId = data['task_id'] ?? 'unknown';
//       final alarmId = data['alarm_id'] ?? 'unknown';
//       String title = data['title'] ?? 'New Task';
//       String? message;
//       tz.TZDateTime? alarmTime;
//
//       if (type == 'task_created') {
//         final creatorName = data['creator_name'] ?? 'Someone';
//         final description = data['description'] ?? '';
//         final status = data['status']?.toUpperCase() ?? 'UNKNOWN';
//         title = 'Task Created: ${data['title'] ?? 'New Task'}';
//         message = '$creatorName has created a new task: "${data['title'] ?? 'New Task'}". '
//             'Description: $description. '
//             'Status: $status. '
//             'Please review in the Task Management App.';
//         if (data.containsKey('alarm_settings')) {
//           try {
//             final alarmSettings = data['alarm_settings'] is String
//                 ? jsonDecode(data['alarm_settings'])
//                 : data['alarm_settings'];
//             final startDate = alarmSettings['start_date'];
//             final startTime = alarmSettings['start_time'];
//             if (startDate != null && startTime != null) {
//               print('Scheduling alarm for task: $taskId');
//               print('Alarm settings: $alarmSettings');
//               String formattedStartTime = startTime;
//               if (startTime.split(':').length == 2) {
//                 formattedStartTime = '$startTime:00';
//               }
//               final alarmDateTime = DateTime.parse('$startDate $formattedStartTime');
//               alarmTime = tz.TZDateTime.from(alarmDateTime, tz.local);
//               final now = tz.TZDateTime.now(tz.local);
//               if (alarmTime.isBefore(now)) {
//                 print('Alarm time in past, setting to now + 30s');
//                 alarmTime = now.add(Duration(seconds: 30));
//               }
//               await _persistAlarm({
//                 'alarm_id': alarmId,
//                 'task_id': taskId,
//                 'title': data['title'] ?? 'New Task',
//                 'trigger_time': alarmTime.toIso8601String(),
//               });
//             }
//           } catch (e) {
//             print('Error parsing alarm_settings: $e');
//           }
//         }
//       } else if (type == 'set_alarm') {
//         title = data['title'] ?? 'Task Alarm';
//         message = data['description'] ?? 'Task alarm triggered!';
//         final triggerTime = data['trigger_time'];
//         if (triggerTime != null) {
//           try {
//             final triggerDateTime = DateTime.parse(triggerTime);
//             alarmTime = tz.TZDateTime.from(triggerDateTime, tz.local);
//             final now = tz.TZDateTime.now(tz.local);
//             if (alarmTime.isBefore(now)) {
//               print('Alarm time in past, setting to now + 30s');
//               alarmTime = now.add(Duration(seconds: 30));
//             }
//             await _persistAlarm({
//               'alarm_id': alarmId,
//               'task_id': taskId,
//               'title': data['title'] ?? 'Task Alarm',
//               'trigger_time': alarmTime.toIso8601String(),
//             });
//           } catch (e) {
//             print('Error parsing trigger_time: $e');
//           }
//         }
//       }
//
//       if (alarmTime != null) {
//         await AlarmService().setAlarm(
//           alarmTime: alarmTime,
//           alarmId: alarmId,
//           taskId: taskId,
//           taskTitle: data['title'] ?? 'New Task',
//         );
//         print('Alarm scheduled for $alarmTime (Task: ${data['title'] ?? 'New Task'}, ID: $taskId, Alarm ID: $alarmId)');
//       }
//
//       if (message != null) {
//         try {
//           const channelId = 'task_alarms';
//           const channel = AndroidNotificationChannel(
//             channelId,
//             'Task Alarms',
//             description: 'High priority notifications for task alarms',
//             importance: Importance.max,
//             playSound: true,
//             showBadge: true,
//             audioAttributesUsage: AudioAttributesUsage.alarm,
//           );
//           await FlutterLocalNotificationsPlugin()
//               .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//               ?.createNotificationChannel(channel);
//           final androidDetails = AndroidNotificationDetails(
//             channel.id,
//             channel.name,
//             channelDescription: channel.description,
//             importance: Importance.max,
//             priority: Priority.max,
//             playSound: true,
//             ticker: 'ticker',
//             visibility: NotificationVisibility.public,
//             enableVibration: true,
//             enableLights: true,
//             color: const Color(0xFF2196F3),
//             ledColor: const Color(0xFF2196F3),
//             ledOnMs: 1000,
//             ledOffMs: 500,
//           );
//           const iosDetails = DarwinNotificationDetails(
//             presentAlert: true,
//             presentBadge: true,
//             presentSound: true,
//           );
//           final notificationDetails = NotificationDetails(
//             android: androidDetails,
//             iOS: iosDetails,
//           );
//           await FlutterLocalNotificationsPlugin().show(
//             taskId.hashCode,
//             title,
//             message,
//             notificationDetails,
//             payload: jsonEncode(data),
//           );
//           print('Local notification shown: $title');
//         } catch (e, stackTrace) {
//           debugPrint('❌ Error showing local notification: $e\n$stackTrace');
//         }
//       }
//     } catch (e) {
//       print('Error showing local notification: $e');
//     }
//   }
//
//   static Future<void> _persistAlarm(Map<String, dynamic> alarm) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final alarmsJson = prefs.getString(_alarmsKey) ?? '[]';
//       final alarms = jsonDecode(alarmsJson) as List<dynamic>;
//       alarms.removeWhere((a) => a['alarm_id'] == alarm['alarm_id']);
//       alarms.add(alarm);
//       await prefs.setString(_alarmsKey, jsonEncode(alarms));
//       print('Persisted alarm: ${alarm['alarm_id']}');
//     } catch (e) {
//       print('Error persisting alarm: $e');
//     }
//   }
//
//   static Future<void> _restoreAlarms() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final alarmsJson = prefs.getString(_alarmsKey) ?? '[]';
//       final alarms = jsonDecode(alarmsJson) as List<dynamic>;
//       for (var alarm in alarms) {
//         final alarmId = alarm['alarm_id'];
//         final taskId = alarm['task_id'];
//         final title = alarm['title'];
//         final triggerTime = alarm['trigger_time'];
//         if (triggerTime != null) {
//           try {
//             final triggerDateTime = DateTime.parse(triggerTime);
//             tz.TZDateTime alarmTime = tz.TZDateTime.from(triggerDateTime, tz.local);
//             final now = tz.TZDateTime.now(tz.local);
//             if (alarmTime.isBefore(now)) {
//               alarmTime = now.add(Duration(seconds: 30));
//             }
//             await AlarmService().setAlarm(
//               alarmTime: alarmTime,
//               alarmId: alarmId,
//               taskId: taskId,
//               taskTitle: title,
//             );
//             print('Restored alarm: $alarmId for task: $taskId');
//           } catch (e) {
//             print('Error restoring alarm: $e');
//           }
//         }
//       }
//     } catch (e) {
//       print('Error restoring alarms: $e');
//     }
//   }
//
//   void _handleNotificationTap(String payload) {
//     try {
//       final data = jsonDecode(payload);
//       print('Notification tap data: $data');
//       if (data['type'] == 'set_alarm') {
//         // Get.to(() => AlarmScreen(
//         //   taskId: data['task_id'] ?? '',
//         //   alarmId: data['alarm_id'] ?? '',
//         //   taskTitle: data['title'] ?? 'Task Alarm',
//         //   assigneeName: data['assignee_name'] ?? '',
//         //   assignedBy: data['assigned_by'] ?? 'Unknown',
//         //   dueDate: data['deadline'] ?? '',
//         // ));
//       } else {
//         Get.to(() => NotificationScreen());
//       }
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error handling notification tap: $e\n$stackTrace');
//     }
//   }
//
//   Future<List<NotificationModel>> getNotifications() async {
//     try {
//       print('🔔 [NotificationFirebaseService] Fetching notifications');
//       final prefs = await SharedPreferences.getInstance();
//       final userId = prefs.getString('user_id');
//       final username = prefs.getString('username');
//       if (userId == null || username == null) {
//         print('❌ [NotificationFirebaseService] User not logged in');
//         throw Exception('User not logged in');
//       }
//       final response = await http.get(
//         Uri.parse('${ApiService.baseUrl}/tasks/notifications?user_id=$userId&username=$username'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//       ).timeout(const Duration(seconds: 10));
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = json.decode(response.body);
//         if (responseData['success'] == true && responseData['notifications'] != null) {
//           final List<dynamic> notifications = responseData['notifications'];
//           final processedNotifications = notifications
//               .map((json) {
//             if ((json['updated_by'] != null && json['updated_by'] == username) ||
//                 (json['assigned_by'] != null && json['assigned_by'] == username)) {
//               return null;
//             }
//             return NotificationModel(
//               id: json['id'] ?? '',
//               title: json['title'] ?? '',
//               description: json['description'] ?? '',
//               senderName: json['sender_name'] ?? '',
//               senderRole: json['sender_role'] ?? '',
//               createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
//               type: _getNotificationType(json['type'] ?? json['priority'] ?? ''),
//               isCompleted: json['is_read'] == 1,
//             );
//           })
//               .where((notification) => notification != null)
//               .cast<NotificationModel>()
//               .toList();
//           print('✅ [NotificationFirebaseService] Processed ${processedNotifications.length} notifications');
//           return processedNotifications;
//         }
//         print('ℹ️ [NotificationFirebaseService] No notifications found');
//         return [];
//       }
//       throw Exception('Failed to load notifications: ${response.statusCode}');
//     } catch (e, stackTrace) {
//       print('❌ [NotificationFirebaseService] Error fetching notifications: $e\n$stackTrace');
//       return [];
//     }
//   }
//
//   Future<void> markNotificationAsComplete(String notificationId) async {
//     try {
//       final response = await _apiService.markNotificationAsComplete(notificationId);
//       if (!response['success']) {
//         throw Exception(response['message'] ?? 'Failed to mark notification as complete');
//       }
//     } catch (e) {
//       print('❌ [NotificationService] Error marking notification as complete: $e');
//       rethrow;
//     }
//   }
//
//   void setUnreadState(bool hasUnread) {
//     _hasUnreadNotifications = hasUnread;
//   }
//
//   bool getUnreadState() {
//     return _hasUnreadNotifications;
//   }
//
//   String _getNotificationType(String input) {
//     final lower = input.toLowerCase();
//     if (lower.contains('task') || lower == 'high' || lower == 'urgent') {
//       return 'task';
//     } else if (lower.contains('meet')) {
//       return 'meeting';
//     } else {
//       return 'system';
//     }
//   }
//
//   void dispose() {
//     // No disposal needed for singleton AlarmService
//   }
// }


import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskmanagement/services/api_service.dart';

//import '../screens/notification_screen.dart';
import '../models/notification_model.dart';
import '../screens/notifications_screen.dart'; // Adjust path to your NotificationScreen

/// A singleton service for managing Firebase Cloud Messaging (FCM) push notifications.
/// Handles permission requests, foreground/background/terminated notifications,
/// and local notification display with navigation.
class NotificationFirebaseService {
  // Singleton instance
  static final NotificationFirebaseService _instance = NotificationFirebaseService._internal();
  factory NotificationFirebaseService() => _instance;
  NotificationFirebaseService._internal();

  // Dependencies
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Flag to prevent multiple permission requests
  bool _permissionRequested = false;
  final ApiService _apiService = ApiService();

  static bool _hasUnreadNotifications = false;

  /// Initializes the notification service, setting up permissions, local notifications,
  /// and listeners for all notification scenarios.
  Future<void> initialize() async {
    try {
      // Request notification permissions
      await requestNotificationPermission();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Set up token refresh listener
      _setupTokenRefreshListener();

      // Configure FCM listeners
      await _configureFcmListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ Notification initialization failed: $e\n$stackTrace');
    }
  }

  /// Requests notification permissions with a user-friendly prompt.
  Future<void> requestNotificationPermission() async {
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
      debugPrint('📱 FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
      return null;
    }
  }

  /// Initializes local notifications for Android and iOS with tap handling.
  Future<void> _initializeLocalNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) => _handleNotificationTap(response.payload),
      );
    } catch (e) {
      debugPrint('❌ Failed to initialize local notifications: $e');
    }
  }

  /// Sets up a listener for FCM token refresh events.
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 New FCM Token: $newToken');
      // TODO: Send new token to your server for targeting notifications
      debugPrint('FCM Token Refreshed: $newToken');


      //Saving new Token in db and Shared Preference
      final getPrefs = await SharedPreferences.getInstance();
      final currentUser = await getPrefs.getString('username');
      final fcmToken = getPrefs.getString('fcm_token');

      ApiService().updateFcmToken(currentUser!, fcmToken!);

      //ApiService().updateFcmToken(username, fcmToken)

    }).onError((e) {
      debugPrint('❌ Error on token refresh: $e');
    });
  }

  /// Configures FCM listeners for foreground, background, and terminated states.
  Future<void> _configureFcmListeners() async {
    try {
      // Set iOS foreground notification options
      if (Platform.isIOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Handle terminated state notifications
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

      // Set up background message handler
      //FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('❌ Error configuring FCM listeners: $e');
    }
  }

  /// Handles foreground notifications by displaying a local notification.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {

    print("Hello Hello Hello ${message}");
    debugPrint('📩 Foreground Notification: ${message.notification?.title}');
    await showLocalNotification(message);
  }

  /// Handles background/terminated notification taps, navigating to the appropriate screen.
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('📩 Background/Terminated Notification: ${message.notification?.title}');
    _handleNotificationTap(jsonEncode(message.data));
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

  /// Background message handler (top-level function required by FCM).

  /// Displays a local notification for the given FCM message.
  // Future<void> showLocalNotification(RemoteMessage message) async {
  //   final notification = message.notification;
  //   if (notification == null) return;
  //
  //   try {
  //     const channelId = 'high_importance_channel';
  //     const channel = AndroidNotificationChannel(
  //       channelId,
  //       'High Importance Notifications',
  //       description: 'Used for important notifications',
  //       importance: Importance.max,
  //       playSound: true,
  //       showBadge: true,
  //
  //
  //       // Added custom sound for Android channel
  //       // sound: RawResourceAndroidNotificationSound('alarm'),
  //     );
  //
  //     // Create notification channel for Android
  //     await _localNotificationsPlugin
  //         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
  //         ?.createNotificationChannel(channel);
  //
  //     final androidDetails = AndroidNotificationDetails(
  //       channel.id,
  //       channel.name,
  //       channelDescription: channel.description,
  //       importance: Importance.max,
  //       priority: Priority.max,
  //       playSound: true,
  //       ticker: 'ticker',
  //       // Added custom sound for Android notification
  //       // sound: const RawResourceAndroidNotificationSound('alarm'),
  //     );
  //
  //     const iosDetails = DarwinNotificationDetails(
  //       presentAlert: true,
  //       presentBadge: true,
  //       presentSound: true,
  //       // Added custom sound for iOS notification
  //       // sound: 'alarm.mp3',
  //     );
  //
  //     final notificationDetails = NotificationDetails(
  //       android: androidDetails,
  //       iOS: iosDetails,
  //     );
  //
  //     await _localNotificationsPlugin.show(
  //       notification.hashCode,
  //       notification.title,
  //       notification.body,
  //       notificationDetails,
  //       payload: jsonEncode(message.data),
  //     );
  //   } catch (e) {
  //     debugPrint('❌ Failed to show local notification: $e');
  //   }
  // }

    Future<void> snoozeNotification(String notificationId, DateTime snoozeUntil, {String? reason, Map<String, dynamic>? audioNote}) async {
    try {
      print('🔄 [NotificationSnooze] Starting snooze request');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');
      final token = prefs.getString('access_token');

      if (userId == null || username == null) {
        throw Exception('User not logged in');
      }

      print('🔄 [NotificationSnooze] User: $username, ID: $userId');

      // Use HTTPS protocol
      final baseUrl = ApiService.baseUrl;

      // First, get the task ID from the notification
      print('🔄 [NotificationSnooze] Fetching notification details from: $baseUrl/tasks/notifications');
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // Add auth token
        },
      ).timeout(const Duration(seconds: 10));

      print('🔄 [NotificationSnooze] Notification details response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          final notification = notifications.firstWhere(
            (n) => n['id'] == notificationId,
            orElse: () => throw Exception('Notification not found')
          );

          print('🔄 [NotificationSnooze] Found notification: ${notification['id']}');

          // Create the request payload
          Map<String, dynamic> payload = {
            'notification_id': notificationId,
            'snooze_until': snoozeUntil.toIso8601String(),
            'reason': reason,
            'updated_by': username,
          };

          // Only add audio note if it exists
          if (audioNote != null) {
            // Create a proper audio_note structure
            payload['audio_note'] = {
              'audio_data': audioNote['audio_data'],
              'duration': audioNote['duration'] ?? 0,
              'filename': audioNote['filename'] ?? 'voice_note.wav'
            };
          }

          print('🔄 [NotificationSnooze] Payload structure: ${payload.keys.join(', ')}');
          print('🔄 [NotificationSnooze] Payload: ${json.encode(payload)}');

          // Snooze the notification
          final snoozeResponse = await http.post(
            Uri.parse('$baseUrl/notifications/snooze'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token', // Add auth token
            },
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 10));

          print('🔄 [NotificationSnooze] Response status: ${snoozeResponse.statusCode}');
          print('🔄 [NotificationSnooze] Response headers: ${snoozeResponse.headers}');
          print('🔄 [NotificationSnooze] Response body: ${snoozeResponse.body.substring(0, math.min(500, snoozeResponse.body.length))}');

          if (snoozeResponse.statusCode == 200 || snoozeResponse.statusCode == 201) {
            print('✅ [NotificationSnooze] Notification snoozed successfully');
            // Mark the notification as read to clear it from the notification bar
            await markNotificationAsComplete(notificationId);
          } else {
            print('❌ [NotificationSnooze] Failed to snooze notification: ${snoozeResponse.statusCode}');
            try {
              final errorBody = json.decode(snoozeResponse.body);
              final errorMessage = errorBody['message'] ?? 'Failed to snooze notification';
              throw Exception(errorMessage);
            } catch (e) {
              throw Exception('Failed to snooze notification: ${snoozeResponse.statusCode}');
            }
          }
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [NotificationSnooze] Error snoozing notification: $e');
      rethrow;
    }
  }



  Future<void> showLocalNotification(RemoteMessage message) async {
    try {
      debugPrint('🔔 Starting to show local notification');
      debugPrint('📩 Full message data: ${message.data}');

      final notification = message.notification;
      if (notification == null) {
        debugPrint('⚠️ Notification payload is null - skipping');
        return;
      }

      debugPrint('📢 Notification received:');
      debugPrint('   Title: ${notification.title}');
      debugPrint('   Body: ${notification.body}');
      // debugPrint('   Sound: ${message.notification?.sound ?? 'Not specified'}');

      // Channel configuration
      const channelId = 'high_importance_channel';
      const channelName = 'High Importance Notifications';
      const channelDescription = 'Used for important notifications';

      debugPrint('🔈 Configuring notification channel...');
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
      );

      // Create Android notification channel
      try {
        final androidPlugin = _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          debugPrint('🤖 Android platform detected - creating channel');
          await androidPlugin.createNotificationChannel(channel);
          debugPrint('✅ Android notification channel created successfully');
        } else {
          debugPrint('⚠️ Not on Android - skipping channel creation');
        }
      } catch (e) {
        debugPrint('❌ Failed to create Android notification channel: $e');
      }

      // Notification details
      debugPrint('🎛 Configuring notification details...');

      // Android-specific details
      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        ticker: 'ticker',
        sound: const RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
      );

      debugPrint('📱 Android notification details:');
      debugPrint('   Channel ID: ${androidDetails.channelId}');
      debugPrint('   Sound: ${androidDetails.sound}');
      debugPrint('   PlaySound: ${androidDetails.playSound}');

      // iOS-specific details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarm.mp3',
        badgeNumber: 1,
      );

      debugPrint('🍏 iOS notification details:');
      debugPrint('   PresentSound: ${iosDetails.presentSound}');
      debugPrint('   Sound: ${iosDetails.sound}');

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show the notification
      debugPrint('🔼 Attempting to display notification...');
      try {
        await _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          notificationDetails,
          payload: jsonEncode(message.data),
        );
        debugPrint('✅ Notification displayed successfully');

        // Verify sound settings
        if (Platform.isAndroid) {
          debugPrint('🔊 Android sound verification:');
          debugPrint('   Channel sound: ${channel.sound}');
          debugPrint('   Notification sound: ${androidDetails.sound}');
        } else if (Platform.isIOS) {
          debugPrint('🔊 iOS sound verification:');
          debugPrint('   Sound file: ${iosDetails.sound}');
        }
      } catch (e) {
        debugPrint('❌ Failed to display notification: $e');

        // Fallback to default sound
        debugPrint('🔄 Attempting fallback with default sound...');
        try {
          final fallbackDetails = NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              sound: const UriAndroidNotificationSound('default'),
            ),
            iOS: const DarwinNotificationDetails(
              presentSound: true,
              sound: 'default',
            ),
          );

          await _localNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            fallbackDetails,
            payload: jsonEncode(message.data),
          );
          debugPrint('✅ Fallback notification with default sound displayed');
        } catch (fallbackError) {
          debugPrint('❌ Fallback notification failed: $fallbackError');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('‼️ Critical error in showLocalNotification: $e');
      debugPrint('🛑 Stack trace: $stackTrace');
    }
  }

    void setUnreadState(bool hasUnread) {
    _hasUnreadNotifications = hasUnread;
  }

  bool getUnreadState() {
    return _hasUnreadNotifications;
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

  Future<List<NotificationModel>> getNotifications() async {
    try {
      print('🔔 [NotificationFirebaseService] Fetching notifications');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');
      if (userId == null || username == null) {
        print('❌ [NotificationFirebaseService] User not logged in');
        throw Exception('User not logged in');
      }
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          final processedNotifications = notifications
              .map((json) {
            if ((json['updated_by'] != null && json['updated_by'] == username) ||
                (json['assigned_by'] != null && json['assigned_by'] == username)) {
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
          })
              .where((notification) => notification != null)
              .cast<NotificationModel>()
              .toList();
          print('✅ [NotificationFirebaseService] Processed ${processedNotifications.length} notifications');
          return processedNotifications;
        }
        print('ℹ️ [NotificationFirebaseService] No notifications found');
        return [];
      }
      throw Exception('Failed to load notifications: ${response.statusCode}');
    } catch (e, stackTrace) {
      print('❌ [NotificationFirebaseService] Error fetching notifications: $e\n$stackTrace');
      return [];
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
      // Example: Navigate based on notification type
      switch (data['type']) {
        case 'message':
          Get.to(() => NotificationScreen());
          // TODO: Navigate to a specific message screen
          break;
        case 'order':
          Get.to(() => NotificationScreen());
          // TODO: Navigate to an order details screen
          break;
        default:
          Get.to(() => NotificationScreen());
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
      Get.to(() => const NotificationScreen());
    }
  }
}
