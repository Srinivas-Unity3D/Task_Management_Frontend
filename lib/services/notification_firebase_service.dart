// import 'dart:convert';
// import 'dart:io';
//
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:get/get.dart';
// import 'package:app_settings/app_settings.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:taskmanagement/services/api_service.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:http/http.dart' as http;
// import 'package:audioplayers/audioplayers.dart';
// import 'package:taskmanagement/services/notification_service.dart';
//
// //import '../screens/notification_screen.dart';
// import '../screens/notifications_screen.dart'; // Adjust path to your NotificationScreen
// import '../screens/alarm_screen.dart'; // Adjust path to your AlarmScreen
//
// /// A singleton service for managing Firebase Cloud Messaging (FCM) push notifications.
// /// Handles permission requests, foreground/background/terminated notifications,
// /// and local notification display with navigation.
// @pragma('vm:entry-point')
// class NotificationFirebaseService {
//   // Singleton instance
//   static final NotificationFirebaseService _instance = NotificationFirebaseService._internal();
//   factory NotificationFirebaseService() => _instance;
//   NotificationFirebaseService._internal();
//
//   // Dependencies
//   late FirebaseMessaging _messaging;
//   final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
//   final AudioPlayer _audioPlayer = AudioPlayer();
//
//   // Flag to prevent multiple permission requests
//   bool _permissionRequested = false;
//
//   /// Initializes the notification service, setting up permissions, local notifications,
//   /// and listeners for all notification scenarios.
//   Future<void> initialize() async {
//     try {
//       print('🔄 Initializing NotificationFirebaseService...');
//
//       // Initialize Firebase Messaging
//       await Firebase.initializeApp();
//       _messaging = FirebaseMessaging.instance;
//
//       // Request notification permissions
//       NotificationSettings settings = await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//         provisional: false,
//         criticalAlert: true,
//       );
//       print('📱 Notification permission status: ${settings.authorizationStatus}');
//
//       // Get FCM token
//       String? token = await _messaging.getToken();
//       print('🔑 FCM Token: $token');
//
//       // Create notification channel for Android
//       const AndroidNotificationChannel channel = AndroidNotificationChannel(
//         'task_alarms',
//         'Task Alarms',
//         description: 'High priority notifications for task alarms',
//         importance: Importance.max,
//         playSound: true,
//         enableVibration: true,
//         enableLights: true,
//         showBadge: true,
//         sound: RawResourceAndroidNotificationSound('alarm'),
//       );
//
//       // Create the Android notification channel
//       await _localNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//
//       print('✅ Notification channel created successfully');
//
//       // Initialize local notifications
//       const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
//       const iosInit = DarwinInitializationSettings(
//         requestAlertPermission: false,
//         requestBadgePermission: false,
//         requestSoundPermission: false,
//       );
//       const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
//
//       await _localNotificationsPlugin.initialize(
//         initSettings,
//         onDidReceiveNotificationResponse: (response) {
//           final payload = response.payload;
//           if (payload != null) {
//             final data = jsonDecode(payload);
//             if (response.actionId == 'snooze') {
//               stopAlarm();
//               Get.to(() => const AlarmScreen(), arguments: {
//                 'task_id': data['task_id'],
//                 'alarm_id': data['alarm_id'],
//                 'title': data['title'],
//                 'show_snooze': true,
//               });
//             } else if (response.actionId == 'dismiss') {
//               stopAlarm();
//             } else {
//               _handleNotificationTap(payload);
//             }
//           }
//         },
//       );
//
//       // Set up background message handler
//       FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//       // Handle foreground messages
//       FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//         print('📱 Received foreground message: ${message.messageId}');
//         _handleMessage(message);
//       });
//
//       // Handle notification tap when app is in background
//       FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//         print('📱 Notification tapped: ${message.messageId}');
//         _handleMessage(message);
//       });
//
//       print('✅ NotificationFirebaseService initialized successfully');
//     } catch (e) {
//       print('❌ Error initializing NotificationFirebaseService: $e');
//     }
//   }
//
//   /// Requests notification permissions with a user-friendly prompt.
//   Future<void> _requestNotificationPermission() async {
//     if (_permissionRequested) return;
//     _permissionRequested = true;
//
//     try {
//       final settings = await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//         announcement: false,
//         criticalAlert: false,
//         provisional: false,
//       );
//
//       if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//         debugPrint('✅ Notification permission granted.');
//       } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
//         debugPrint('⚠️ Provisional permission granted.');
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
//     } catch (e) {
//       debugPrint('❌ Error requesting notification permission: $e');
//     }
//   }
//
//   /// Retrieves the FCM device token for targeting notifications.
//   Future<String?> getDeviceToken() async {
//     try {
//       final token = await _messaging.getToken();
//       debugPrint('📱 FCM Token: ${token?.substring(0, 20)}...');
//
//       // When token is refreshed, update on backend
//       // This will also be handled by the ApiService token refresh listener
//       _updateFcmTokenOnBackend(token);
//
//       return token;
//     } catch (e) {
//       debugPrint('❌ Failed to get FCM token: $e');
//       return null;
//     }
//   }
//
//   /// Send FCM token to backend to enable push notifications
//   Future<void> _updateFcmTokenOnBackend(String? token) async {
//     if (token == null) return;
//
//     try {
//       final prefs = await Get.find<SharedPreferences>();
//       final username = prefs.getString('username');
//
//       if (username == null) {
//         debugPrint('⚠️ Cannot update FCM token on backend: No logged in user');
//         return;
//       }
//
//       debugPrint('🔄 Updating FCM token on backend for user: $username');
//
//       // Call API service to update token in backend
//       // This is also handled by ApiService.setupFcmTokenRefreshListener
//       // but we also do it here to ensure the token is set during initialization
//
//       // Implement direct API call if needed
//     } catch (e) {
//       debugPrint('❌ Error updating FCM token on backend: $e');
//     }
//   }
//
//   /// Handles incoming messages from Firebase Cloud Messaging.
//   Future<void> _handleMessage(RemoteMessage message) async {
//     try {
//       print('📱 Handling message: [32m${message.messageId}[0m');
//       print('📱 Message data: ${message.data}');
//       print('📱 Notification: ${message.notification?.title} - ${message.notification?.body}');
//
//       // Check if this is an alarm notification
//       final bool isAlarm = message.data['type'] == 'task_alarm' ||
//                           (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
//
//       if (isAlarm) {
//         // Show alarm notification
//         await _showAlarmNotification(message);
//         // Trigger alarm sound and vibration
//         await _triggerAlarm(message.data);
//         // Show foreground alarm screen
//         print('🚨 Attempting to navigate to AlarmScreen in foreground');
//         try {
//           Get.to(() => AlarmScreen(
//             taskId: message.data['task_id'],
//             alarmId: message.data['alarm_id'],
//             taskTitle: message.data['title'],
//             assigneeName: message.data['assignee_name'],
//             assignedBy: message.data['assigned_by'],
//             dueDate: message.data['deadline'],
//           ));
//         } catch (e) {
//           print('❌ Get.to() navigation failed, trying global navigator key: $e');
//           try {
//             globalNavigatorKey.currentState?.push(
//               MaterialPageRoute(
//                 builder: (context) => AlarmScreen(
//                   taskId: message.data['task_id'],
//                   alarmId: message.data['alarm_id'],
//                   taskTitle: message.data['title'],
//                   assigneeName: message.data['assignee_name'],
//                   assignedBy: message.data['assigned_by'],
//                   dueDate: message.data['deadline'],
//                 ),
//                 fullscreenDialog: true,
//               ),
//             );
//           } catch (e2) {
//             print('❌ Global navigator key navigation also failed: $e2');
//           }
//         }
//       } else {
//         // Show regular notification without alarm sound
//         await _showLocalNotification(message);
//         // Only navigate to notification screen for non-alarm notifications
//         _handleNotificationTap(jsonEncode(message.data));
//       }
//     } catch (e) {
//       print('❌ Error handling message: $e');
//     }
//   }
//
//   /// Displays a local notification for the given FCM message.
//   Future<void> _showLocalNotification(RemoteMessage message) async {
//     print("📲 _showLocalNotification from notification_firebase_service called");
//
//     final notification = message.notification;
//     if (notification == null) return;
//
//     try {
//       const channelId = 'task_alarms';
//       const channel = AndroidNotificationChannel(
//         channelId,
//         'High Importance Notifications',
//         description: 'Used for critical alerts',
//         importance: Importance.max,
//         playSound: true,
//         sound: RawResourceAndroidNotificationSound('alarm'),
//         enableVibration: true,
//         enableLights: true,
//       );
//
//       // Create notification channel for Android
//       await _localNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//
//       final androidDetails = AndroidNotificationDetails(
//         channel.id,
//         channel.name,
//         channelDescription: channel.description,
//         importance: Importance.max,
//         priority: Priority.max,
//         playSound: true,
//         sound: const RawResourceAndroidNotificationSound('alarm'),
//         enableVibration: true,
//         enableLights: true,
//         fullScreenIntent: true,
//         category: AndroidNotificationCategory.alarm,
//         visibility: NotificationVisibility.public,
//         color: const Color(0xFF2196F3),
//         ledColor: const Color(0xFF2196F3),
//         ledOnMs: 1000,
//         ledOffMs: 500,
//         // actions: [
//         //   const AndroidNotificationAction('stop', 'Stop Alarm'),
//         // ],
//       );
//
//       const iosDetails = DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//         sound: 'alarm.mp3',
//         interruptionLevel: InterruptionLevel.timeSensitive,
//       );
//
//       final notificationDetails = NotificationDetails(
//         android: androidDetails,
//         iOS: iosDetails,
//       );
//
//       await _localNotificationsPlugin.show(
//         notification.hashCode,
//         notification.title,
//         notification.body,
//         notificationDetails,
//         payload: jsonEncode(message.data),
//       );
//     } catch (e) {
//       print('❌ Failed to show local notification: $e');
//     }
//   }
//
//   /// Shows an alarm notification
//   Future<void> _showAlarmNotification(RemoteMessage message) async {
//     try {
//       const channelId = 'task_alarms';
//       const channel = AndroidNotificationChannel(
//         channelId,
//         'Task Alarms',
//         description: 'High priority notifications for task alarms',
//         importance: Importance.max,
//         playSound: true,
//         enableVibration: true,
//         enableLights: true,
//         showBadge: true,
//         // sound: RawResourceAndroidNotificationSound('alarm'),
//       );
//
//       // Create notification channel for Android
//       await _localNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//
//       // Get task details from message data
//       final taskTitle = message.data['title'] ?? 'Task Alarm';
//       final assignedBy = message.data['assigned_by'] ?? 'Unknown';
//       final deadline = message.data['deadline'] ?? '';
//       final taskId = message.data['task_id'] ?? '';
//       final alarmId = message.data['alarm_id'] ?? '';
//
//       // Create notification content
//       final notificationContent = '''
// Task: $taskTitle
// Assigned by: $assignedBy
// Deadline: $deadline
// ''';
//
//       final androidDetails = AndroidNotificationDetails(
//         channel.id,
//         channel.name,
//         channelDescription: channel.description,
//         importance: Importance.max,
//         priority: Priority.high,
//         // sound: const RawResourceAndroidNotificationSound('alarm'),
//         fullScreenIntent: true,
//         category: AndroidNotificationCategory.alarm,
//         visibility: NotificationVisibility.public,
//         playSound: true,
//         enableVibration: true,
//         enableLights: true,
//         color: const Color(0xFF2196F3),
//         ledColor: const Color(0xFF2196F3),
//         ledOnMs: 1000,
//         ledOffMs: 500,
//         actions: [
//           const AndroidNotificationAction(
//             'snooze',
//             'Snooze',
//             showsUserInterface: true,
//             cancelNotification: false,
//           ),
//           const AndroidNotificationAction(
//             'dismiss',
//             'Dismiss',
//             cancelNotification: true,
//           ),
//         ],
//         styleInformation: BigTextStyleInformation(
//           notificationContent,
//           htmlFormatBigText: true,
//           contentTitle: taskTitle,
//           htmlFormatContentTitle: true,
//         ),
//       );
//
//       const iosDetails = DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//         sound: 'alarm.mp3',
//         interruptionLevel: InterruptionLevel.timeSensitive,
//         categoryIdentifier: 'TASK_ALARM',
//         threadIdentifier: 'task_alarms',
//       );
//
//       final notificationDetails = NotificationDetails(
//         android: androidDetails,
//         iOS: iosDetails,
//       );
//
//       await _localNotificationsPlugin.show(
//         message.hashCode,
//         'Task Alarm',
//         notificationContent,
//         notificationDetails,
//         payload: jsonEncode({
//           ...message.data,
//           'action': 'task_alarm',
//         }),
//       );
//     } catch (e) {
//       print('❌ Failed to show alarm notification: $e');
//     }
//   }
//
//   /// Handles notification taps, navigating to the appropriate screen based on payload.
//   void _handleNotificationTap(String? payload) {
//     try {
//       if (payload == null) {
//         // Get.to(() => const NotificationScreen());
//         return;
//       }
//
//       final data = jsonDecode(payload);
//
//       // Don't handle taps for alarm notifications here
//       if (data['type'] == 'task_alarm' || (data.containsKey('task_id') && data.containsKey('alarm_id'))) {
//         return;
//       }
//
//       // Handle notification actions
//       switch (data['action']) {
//         case 'dismiss':
//           stopAlarm();
//           return;
//         case 'snooze':
//           stopAlarm();
//           // Navigate to alarm screen with task details
//           Get.to(() => AlarmScreen(
//             taskId: data['task_id'],
//             alarmId: data['alarm_id'],
//             taskTitle: data['title'],
//             assigneeName: data['assignee_name'],
//             assignedBy: data['assigned_by'],
//             dueDate: data['deadline'],
//             showSnooze: true,
//           ));
//           return;
//         // default:
//           // Get.to(() => const NotificationScreen());
//       }
//     } catch (e) {
//       debugPrint('❌ Error handling notification tap: $e');
//       // Get.to(() => const NotificationScreen());
//     }
//   }
//
//   /// Background message handler (top-level function required by FCM).
//   @pragma('vm:entry-point')
//   static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//     try {
//       await Firebase.initializeApp();
//       print('📱 Handling background message: ${message.messageId}');
//       print('📱 Message data: ${message.data}');
//
//       // Initialize notifications plugin
//       final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//           FlutterLocalNotificationsPlugin();
//
//       // Create notification channel for Android
//       const AndroidNotificationChannel channel = AndroidNotificationChannel(
//         'task_alarms',
//         'Task Alarms',
//         description: 'High priority notifications for task alarms',
//         importance: Importance.max,
//         playSound: true,
//         enableVibration: true,
//         enableLights: true,
//         showBadge: true,
//         sound: RawResourceAndroidNotificationSound('alarm'),
//       );
//
//       await flutterLocalNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//
//       // Check if this is an alarm notification
//       final bool isAlarm = message.data['type'] == 'task_alarm' ||
//                           (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
//
//       if (isAlarm) {
//         // Get task details from message data
//         final taskTitle = message.data['title'] ?? 'Task Alarm';
//         final assignedBy = message.data['assigned_by'] ?? 'Unknown';
//         final deadline = message.data['deadline'] ?? '';
//         final taskId = message.data['task_id'] ?? '';
//         final alarmId = message.data['alarm_id'] ?? '';
//
//         // Create notification content
//         final notificationContent = '''
// Task: $taskTitle
// Assigned by: $assignedBy
// Deadline: $deadline
// ''';
//
//         // Show high priority notification
//         final androidDetails = AndroidNotificationDetails(
//           'task_alarms',
//           'Task Alarms',
//           channelDescription: 'High priority notifications for task alarms',
//           importance: Importance.max,
//           priority: Priority.high,
//           sound: const RawResourceAndroidNotificationSound('alarm'),
//           fullScreenIntent: true,
//           category: AndroidNotificationCategory.alarm,
//           visibility: NotificationVisibility.public,
//           playSound: true,
//           enableVibration: true,
//           enableLights: true,
//           color: const Color(0xFF2196F3),
//           ledColor: const Color(0xFF2196F3),
//           ledOnMs: 1000,
//           ledOffMs: 500,
//           actions: [
//             const AndroidNotificationAction(
//               'snooze',
//               'Snooze',
//               showsUserInterface: true,
//               cancelNotification: false,
//             ),
//             const AndroidNotificationAction(
//               'dismiss',
//               'Dismiss',
//               cancelNotification: true,
//             ),
//           ],
//           styleInformation: BigTextStyleInformation(
//             notificationContent,
//             htmlFormatBigText: true,
//             contentTitle: 'Task Alarm',
//             htmlFormatContentTitle: true,
//           ),
//         );
//
//         const iosDetails = DarwinNotificationDetails(
//           presentAlert: true,
//           presentBadge: true,
//           presentSound: true,
//           sound: 'alarm.mp3',
//           interruptionLevel: InterruptionLevel.timeSensitive,
//           categoryIdentifier: 'TASK_ALARM',
//           threadIdentifier: 'task_alarms',
//         );
//
//         final notificationDetails = NotificationDetails(
//           android: androidDetails,
//           iOS: iosDetails,
//         );
//
//         // Show the notification
//         await flutterLocalNotificationsPlugin.show(
//           message.hashCode,
//           'Task Alarm',
//           notificationContent,
//           notificationDetails,
//           payload: jsonEncode({
//             ...message.data,
//             'action': 'task_alarm',
//           }),
//         );
//
//         // Play alarm sound
//         final audioPlayer = AudioPlayer();
//         await audioPlayer.setReleaseMode(ReleaseMode.loop);
//         await audioPlayer.setVolume(1.0);
//         await audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
//         await audioPlayer.resume();
//
//         // Vibrate
//         HapticFeedback.heavyImpact();
//
//         // Handle notification actions
//         flutterLocalNotificationsPlugin.initialize(
//           const InitializationSettings(
//             android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//             iOS: DarwinInitializationSettings(),
//           ),
//           onDidReceiveNotificationResponse: (NotificationResponse response) {
//             final data = jsonDecode(response.payload ?? '{}');
//             switch (data['action']) {
//               case 'dismiss':
//                 audioPlayer.stop();
//                 break;
//               case 'snooze':
//                 audioPlayer.stop();
//                 // The app will be opened by the system due to showsUserInterface: true
//                 break;
//             }
//           },
//         );
//       } else {
//         // Show regular notification without alarm sound
//         final androidDetails = AndroidNotificationDetails(
//           'high_importance_channel',
//           'High Importance Notifications',
//           channelDescription: 'This channel is used for important notifications.',
//           importance: Importance.high,
//           priority: Priority.high,
//         );
//
//         const iosDetails = DarwinNotificationDetails(
//           presentAlert: true,
//           presentBadge: true,
//           presentSound: true,
//         );
//
//         final notificationDetails = NotificationDetails(
//           android: androidDetails,
//           iOS: iosDetails,
//         );
//
//         await flutterLocalNotificationsPlugin.show(
//           message.hashCode,
//           message.notification?.title ?? 'New Notification',
//           message.notification?.body ?? '',
//           notificationDetails,
//           payload: jsonEncode(message.data),
//         );
//       }
//
//       print('✅ Background notification shown successfully');
//     } catch (e) {
//       print('❌ Error handling background message: $e');
//     }
//   }
//
//   /// Triggers the alarm with sound and vibration
//   Future<void> _triggerAlarm(Map<String, dynamic> data) async {
//     try {
//       print('🔔 Triggering alarm...');
//
//       // Initialize audio player
//       await _audioPlayer.setReleaseMode(ReleaseMode.loop);
//       await _audioPlayer.setVolume(1.0);
//       await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
//       await _audioPlayer.resume();
//
//       // Start vibration
//       HapticFeedback.heavyImpact();
//
//       print('✅ Alarm triggered successfully');
//     } catch (e) {
//       print('❌ Error triggering alarm: $e');
//     }
//   }
//
//   /// Stops the alarm
//   Future<void> stopAlarm() async {
//     try {
//       await _audioPlayer.stop();
//       print('✅ Alarm stopped successfully');
//     } catch (e) {
//       print('❌ Error stopping alarm: $e');
//     }
//   }
//
//   /// Disposes the audio player
//   void dispose() {
//     _audioPlayer.dispose();
//   }
// }

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
// import 'package:audioplayers/audioplayers.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:timezone/timezone.dart' as tz;
// import '../controller/alarm_controller.dart';
// import '../screens/alarm_screen.dart';
// import '../screens/notifications_screen.dart';
// import './api_service.dart';
// import '../models/notification_model.dart';
// import 'alarm_service.dart';
//
// @pragma('vm:entry-point')
// class NotificationFirebaseService {
//   final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
//   final AudioPlayer audioPlayer = AudioPlayer();
//   bool _isAlarmPlaying = false;
//   final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   bool _permissionRequested = false;
//   final ApiService _apiService = ApiService();
//   static bool _hasUnreadNotifications = false;
//   bool get isAlarmPlaying => _isAlarmPlaying;
//
//   static final NotificationFirebaseService _instance = NotificationFirebaseService._internal();
//   factory NotificationFirebaseService() => _instance;
//   NotificationFirebaseService._internal() {
//     initialize();
//     print('[Flutter] Initialized NotificationFirebaseService at ${DateTime.now()}');
//   }
//
//   Future<void> initialize() async {
//     try {
//       print('[Flutter] Initializing NotificationFirebaseService...');
//
//       // Request notification and alarm permissions
//       // await _requestPermissions();
//
//       // Initialize local notifications
//       await _initializeLocalNotifications();
//
//       // Set up token refresh listener
//       _setupTokenRefreshListener();
//
//       // Configure FCM listeners
//       await _configureFcmListeners();
//
//       print('[Flutter] NotificationFirebaseService initialized successfully');
//     } catch (e, stackTrace) {
//       debugPrint('❌ Notification initialization failed: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> requestNotificationPermission() async {
//     if (_permissionRequested) return;
//     _permissionRequested = true;
//
//     try {
//       // Request notification permissions
//       final settings = await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//         announcement: false,
//         criticalAlert: false,
//         provisional: false,
//       );
//
//       if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//         debugPrint('✅ Notification permission granted.');
//       } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
//         debugPrint('⚠️ Provisional permission granted.');
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
//
//       // Request SCHEDULE_EXACT_ALARM for Android 12+
//       if (Platform.isAndroid) {
//         final status = await Permission.scheduleExactAlarm.status;
//         if (!status.isGranted) {
//           final result = await Permission.scheduleExactAlarm.request();
//           if (!result.isGranted) {
//             debugPrint('❌ SCHEDULE_EXACT_ALARM permission denied.');
//             Get.snackbar(
//               'Alarm Permission',
//               'Please enable exact alarm permission for background alarms.',
//               snackPosition: SnackPosition.BOTTOM,
//               duration: const Duration(seconds: 4),
//               onTap: (_) => AppSettings.openAppSettings(type: AppSettingsType.settings),
//             );
//           }
//         }
//
//         // Request POST_NOTIFICATIONS for Android 13+
//         final notificationStatus = await Permission.notification.status;
//         if (!notificationStatus.isGranted) {
//           await Permission.notification.request();
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ Error requesting permissions: $e');
//     }
//   }
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
//
//     const androidChannel = AndroidNotificationChannel(
//       'alarm_channel',
//       'Alarm Notifications',
//       description: 'Notifications for alarm triggers',
//       importance: Importance.max,
//       playSound: false,
//       enableLights: true,
//       enableVibration: true,
//       showBadge: true,
//     );
//
//     const taskAlarmsChannel = AndroidNotificationChannel(
//       'task_alarms',
//       'Task Alarms',
//       description: 'High priority notifications for task alarms',
//       importance: Importance.max,
//       playSound: false,
//       enableVibration: true,
//       enableLights: true,
//       showBadge: true,
//     );
//
//     final androidPlugin = _localNotificationsPlugin
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
//
//     try {
//       print('[Flutter] Creating notification channels');
//       await androidPlugin?.createNotificationChannel(androidChannel);
//       await androidPlugin?.createNotificationChannel(taskAlarmsChannel);
//       print('[Flutter] Notification channels created successfully');
//     } catch (e, stackTrace) {
//       print('[Flutter] Error creating notification channels: $e\n$stackTrace');
//     }
//
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
//
//     try {
//       print('[Flutter] Initializing FlutterLocalNotificationsPlugin');
//       await _localNotificationsPlugin.initialize(
//         initializationSettings,
//         onDidReceiveNotificationResponse: (NotificationResponse response) async {
//           print('[Flutter] Notification response received: '
//               'actionId=${response.actionId}, payload=${response.payload}, '
//               'input=${response.input}');
//           try {
//             if (response.actionId == 'snooze') {
//               print('[Flutter] Handling Snooze action');
//               await _stopAlarm();
//               if (response.payload != null) {
//                 final data = jsonDecode(response.payload!);
//                 // await _rescheduleAlarm(data);
//               }
//             } else if (response.actionId == 'dismiss') {
//               print('[Flutter] Handling Dismiss action');
//               await _stopAlarm();
//             } else {
//               print('[Flutter] Handling notification body tap');
//               await _stopAlarm();
//               if (response.payload != null) {
//                 _handleNotificationTap(response.payload!);
//               }
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
//
//     try {
//       print('[Flutter] Requesting notification permissions');
//       final granted = await androidPlugin?.requestNotificationsPermission();
//       print('[Flutter] Notification permission granted: $granted');
//     } catch (e, stackTrace) {
//       print('[Flutter] Error requesting notification permission: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> _stopAlarm() async {
//     try {
//       print('[Flutter] Attempting to stop alarm, current state: ${audioPlayer.state}, isPlaying: $_isAlarmPlaying');
//       if (_isAlarmPlaying || audioPlayer.state == PlayerState.playing) {
//         await audioPlayer.stop();
//         await audioPlayer.release();
//         print('[Flutter] Audio stopped and released, new state: ${audioPlayer.state}');
//         _isAlarmPlaying = false;
//         await _localNotificationsPlugin.cancelAll();
//         print('[Flutter] All notifications cancelled');
//       } else {
//         print('[Flutter] No alarm playing to stop');
//       }
//     } catch (e, stackTrace) {
//       print('[Flutter] Error stopping alarm: $e\n$stackTrace');
//       Get.snackbar('Error', 'Failed to stop alarm: $e');
//     }
//   }
//
//   Future<void> triggerAlarm(BuildContext? context, {bool isFirebase = false}) async {
//     if (_isAlarmPlaying) {
//       print('[Flutter] Alarm already playing');
//       return;
//     }
//
//     try {
//       print('[Flutter] Attempting to load and play alarm.mp3');
//       await audioPlayer.setReleaseMode(ReleaseMode.loop);
//       await audioPlayer.setSource(AssetSource('alarm.mp3'));
//       await audioPlayer.resume();
//       print('[Flutter] Alarm.mp3 started playing, player state: ${audioPlayer.state}');
//       _isAlarmPlaying = true;
//
//       if (!isFirebase) {
//         print('[Flutter] Showing notification');
//         const androidDetails = AndroidNotificationDetails(
//           'alarm_channel',
//           'Alarm Notifications',
//           channelDescription: 'Notifications for alarm triggers',
//           importance: Importance.max,
//           priority: Priority.high,
//           ongoing: false,
//           autoCancel: true,
//           enableLights: true,
//           enableVibration: true,
//           actions: <AndroidNotificationAction>[
//             AndroidNotificationAction('snooze', 'Snooze', showsUserInterface: true),
//             AndroidNotificationAction('dismiss', 'Dismiss', cancelNotification: true),
//           ],
//         );
//         const notificationDetails = NotificationDetails(android: androidDetails);
//
//         try {
//           await _localNotificationsPlugin.show(
//             0,
//             'Alarm Triggered',
//             'Tap Snooze or Dismiss to stop the alarm',
//             notificationDetails,
//           );
//           print('[Flutter] Notification shown successfully');
//         } catch (e, stackTrace) {
//           print('[Flutter] Error showing notification: $e\n$stackTrace');
//           if (context != null && context.mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Failed to show notification: $e')),
//             );
//           } else {
//             Get.snackbar('Error', 'Failed to show notification: $e');
//           }
//         }
//       }
//     } catch (e, stackTrace) {
//       print('[Flutter] Error triggering alarm: $e\n$stackTrace');
//       if (context != null && context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error triggering alarm: $e')),
//         );
//       } else {
//         Get.snackbar('Error', 'Error triggering alarm: $e');
//       }
//     }
//   }
//
//   // Future<void> _scheduleAlarm(Map<String, dynamic> data) async {
//   //   try {
//   //     print('[Flutter] Scheduling alarm for task: ${data['task_id']}');
//   //     const androidDetails = AndroidNotificationDetails(
//   //       'task_alarms',
//   //       'Task Alarms',
//   //       channelDescription: 'High priority notifications for task alarms',
//   //       importance: Importance.max,
//   //       priority: Priority.high,
//   //       ongoing: false,
//   //       autoCancel: true,
//   //       enableLights: true,
//   //       enableVibration: true,
//   //       playSound: false,
//   //       actions: <AndroidNotificationAction>[
//   //         AndroidNotificationAction('snooze', 'Snooze', showsUserInterface: true),
//   //         AndroidNotificationAction('dismiss', 'Dismiss', cancelNotification: true),
//   //       ],
//   //     );
//   //     const iosDetails = DarwinNotificationDetails(
//   //       presentAlert: true,
//   //       presentBadge: true,
//   //       presentSound: false,
//   //       interruptionLevel: InterruptionLevel.timeSensitive,
//   //     );
//   //     final notificationDetails = NotificationDetails(
//   //       android: androidDetails,
//   //       iOS: iosDetails,
//   //     );
//   //
//   //     final taskTitle = data['title'] ?? 'Task Alarm';
//   //     final notificationId = data['task_id'].hashCode;
//   //
//   //     // Schedule the alarm
//   //     await _localNotificationsPlugin.zonedSchedule(
//   //       notificationId,
//   //       'Task Alarm: $taskTitle',
//   //       'Tap Snooze or Dismiss to stop the alarm',
//   //       tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)), // For testing, adjust as needed
//   //       notificationDetails,
//   //       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//   //       uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
//   //       payload: jsonEncode(data),
//   //     );
//   //
//   //     print('[Flutter] Alarm scheduled for task: ${data['task_id']}');
//   //   } catch (e, stackTrace) {
//   //     print('[Flutter] Error scheduling alarm: $e\n$stackTrace');
//   //   }
//   // }
//
//   // Future<void> _rescheduleAlarm(Map<String, dynamic> data) async {
//   //   try {
//   //     print('[Flutter] Rescheduling alarm for task: ${data['task_id']}');
//   //     // Reschedule for 5 minutes later
//   //     final newTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5));
//   //     const androidDetails = AndroidNotificationDetails(
//   //       'task_alarms',
//   //       'Task Alarms',
//   //       channelDescription: 'High priority notifications for task alarms',
//   //       importance: Importance.max,
//   //       priority: Priority.high,
//   //       ongoing: false,
//   //       autoCancel: true,
//   //       enableLights: true,
//   //       enableVibration: true,
//   //       playSound: false,
//   //       actions: <AndroidNotificationAction>[
//   //         AndroidNotificationAction('snooze', 'Snooze', showsUserInterface: true),
//   //         AndroidNotificationAction('dismiss', 'Dismiss', cancelNotification: true),
//   //       ],
//   //     );
//   //     const iosDetails = DarwinNotificationDetails(
//   //       presentAlert: true,
//   //       presentBadge: true,
//   //       presentSound: false,
//   //       interruptionLevel: InterruptionLevel.timeSensitive,
//   //     );
//   //     final notificationDetails = NotificationDetails(
//   //       android: androidDetails,
//   //       iOS: iosDetails,
//   //     );
//   //
//   //     final taskTitle = data['title'] ?? 'Task Alarm';
//   //     final notificationId = data['task_id'].hashCode;
//   //
//   //     await _localNotificationsPlugin.zonedSchedule(
//   //       notificationId,
//   //       'Task Alarm: $taskTitle (Snoozed)',
//   //       'Tap Snooze or Dismiss to stop the alarm',
//   //       newTime,
//   //       notificationDetails,
//   //       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//   //       uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
//   //       payload: jsonEncode(data),
//   //     );
//   //
//   //     print('[Flutter] Alarm rescheduled for task: ${data['task_id']} at $newTime');
//   //   } catch (e, stackTrace) {
//   //     print('[Flutter] Error rescheduling alarm: $e\n$stackTrace');
//   //   }
//   // }
//
//   void _setupTokenRefreshListener() {
//     _messaging.onTokenRefresh.listen((newToken) async {
//       debugPrint('🔄 New FCM Token: $newToken');
//       final prefs = await SharedPreferences.getInstance();
//       final currentUser = prefs.getString('username');
//       final fcmToken = prefs.getString('fcm_token');
//       if (currentUser != null && fcmToken != null) {
//         _apiService.updateFcmToken(currentUser, fcmToken);
//       }
//     }).onError((e) {
//       debugPrint('❌ Error on token refresh: $e');
//     });
//   }
//
//
//
//   Future<void> _configureFcmListeners() async {
//     try {
//       FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
//       FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
//       final initialMessage = await _messaging.getInitialMessage();
//       if (initialMessage != null) {
//         _handleBackgroundMessage(initialMessage);
//       }
//       FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error configuring FCM listeners: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     try {
//       print('📱 Handling foreground message: ${message.messageId}');
//       print('📱 Message data: ${message.data}');
//       print('📱 Notification: ${message.notification?.title} - ${message.notification?.body}');
//
//       final bool isAlarm = message.data['type'] == 'task_alarm' ||
//           (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
//
//       if (isAlarm) {
//         await _showAlarmNotification(message);
//         await triggerAlarm(null, isFirebase: true);
//         // await _scheduleAlarm(message.data); // Schedule for persistence
//       } else {
//         await showLocalNotification(message);
//       }
//     } catch (e, stackTrace) {
//       print('❌ Error handling foreground message: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> _handleBackgroundMessage(RemoteMessage message) async {
//     try {
//       print('📱 Handling background message: ${message.messageId}');
//       print('📱 Message data: ${message.data}');
//       print('📱 Notification: ${message.notification?.title} - ${message.notification?.body}');
//
//       final bool isAlarm = message.data['type'] == 'task_alarm' ||
//           (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
//
//       if (isAlarm) {
//         await _showAlarmNotification(message);
//         await triggerAlarm(null, isFirebase: true);
//         // await _scheduleAlarm(message.data); // Schedule for persistence
//       } else {
//         await showLocalNotification(message);
//       }
//     } catch (e, stackTrace) {
//       print('❌ Error handling background message: $e\n$stackTrace');
//     }
//   }
//
//   @pragma('vm:entry-point')
//   static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//     debugPrint('📩 Background Notification: ${message.notification?.title}');
//     try {
//       // Initialize Flutter binding for plugins
//       WidgetsFlutterBinding.ensureInitialized();
//
//       // Initialize Firebase
//       await Firebase.initializeApp();
//
//       // Initialize the notification plugin in the background isolate
//       final localNotificationsPlugin = FlutterLocalNotificationsPlugin();
//       const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//       const iosSettings = DarwinInitializationSettings();
//       const initializationSettings = InitializationSettings(
//         android: androidSettings,
//         iOS: iosSettings,
//       );
//       await localNotificationsPlugin.initialize(initializationSettings);
//
//       const androidChannel = AndroidNotificationChannel(
//         'alarm_channel',
//         'Alarm Notifications',
//         description: 'Notifications for alarm triggers',
//         importance: Importance.max,
//         playSound: false,
//         enableLights: true,
//         enableVibration: true,
//         showBadge: true,
//       );
//       const taskAlarmsChannel = AndroidNotificationChannel(
//         'task_alarms',
//         'Task Alarms',
//         description: 'High priority notifications for task alarms',
//         importance: Importance.max,
//         playSound: false,
//         enableVibration: true,
//         enableLights: true,
//         showBadge: true,
//       );
//       final androidPlugin = localNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
//       await androidPlugin?.createNotificationChannel(androidChannel);
//       await androidPlugin?.createNotificationChannel(taskAlarmsChannel);
//
//       final service = NotificationFirebaseService();
//       final bool isAlarm = message.data['type'] == 'task_alarm' ||
//           (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
//
//       if (isAlarm) {
//         await service._showAlarmNotification(message);
//         await service.triggerAlarm(null, isFirebase: true);
//         // await service._scheduleAlarm(message.data);
//       } else {
//         await service.showLocalNotification(message);
//       }
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error in background handler: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> showLocalNotification(RemoteMessage message) async {
//     final notification = message.notification;
//     if (notification == null) return;
//
//     try {
//       const channelId = 'high_importance_channel';
//       const channel = AndroidNotificationChannel(
//         channelId,
//         'High Importance Notifications',
//         description: 'Used for important notifications',
//         importance: Importance.max,
//         playSound: true,
//         showBadge: true,
//       );
//
//       await _localNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//
//       final androidDetails = AndroidNotificationDetails(
//         channel.id,
//         channel.name,
//         channelDescription: channel.description,
//         importance: Importance.max,
//         priority: Priority.max,
//         playSound: true,
//         ticker: 'ticker',
//         visibility: NotificationVisibility.public,
//         enableVibration: true,
//         enableLights: true,
//         color: const Color(0xFF2196F3),
//         ledColor: const Color(0xFF2196F3),
//         ledOnMs: 1000,
//         ledOffMs: 500,
//       );
//
//       const iosDetails = DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//       );
//
//       final notificationDetails = NotificationDetails(
//         android: androidDetails,
//         iOS: iosDetails,
//       );
//
//       await _localNotificationsPlugin.show(
//         notification.hashCode,
//         notification.title,
//         notification.body,
//         notificationDetails,
//         payload: jsonEncode(message.data),
//       );
//     } catch (e, stackTrace) {
//       debugPrint('❌ Failed to show local notification: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> _showAlarmNotification(RemoteMessage message) async {
//     try {
//       const channelId = 'task_alarms';
//       const channel = AndroidNotificationChannel(
//         channelId,
//         'Task Alarms',
//         description: 'High priority notifications for task alarms',
//         importance: Importance.max,
//         playSound: false,
//         enableVibration: true,
//         enableLights: true,
//         showBadge: true,
//       );
//
//       await _localNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//
//       final taskTitle = message.data['title'] ?? 'Task Alarm';
//       final assignedBy = message.data['assigned_by'] ?? 'Unknown';
//       final deadline = message.data['deadline'] ?? '';
//       final taskId = message.data['task_id'] ?? '';
//       final alarmId = message.data['alarm_id'] ?? '';
//
//       final notificationContent = '''
// Task: $taskTitle
// Assigned by: $assignedBy
// Deadline: $deadline
// ''';
//
//       final androidDetails = AndroidNotificationDetails(
//         channel.id,
//         channel.name,
//         channelDescription: channel.description,
//         importance: Importance.max,
//         priority: Priority.high,
//         fullScreenIntent: true,
//         category: AndroidNotificationCategory.alarm,
//         visibility: NotificationVisibility.public,
//         playSound: false,
//         enableVibration: true,
//         enableLights: true,
//         color: const Color(0xFF2196F3),
//         ledColor: const Color(0xFF2196F3),
//         ledOnMs: 1000,
//         ledOffMs: 500,
//         actions: [
//           const AndroidNotificationAction('snooze', 'Snooze', showsUserInterface: true, cancelNotification: false),
//           const AndroidNotificationAction('dismiss', 'Dismiss', cancelNotification: true),
//         ],
//         styleInformation: BigTextStyleInformation(
//           notificationContent,
//           htmlFormatBigText: true,
//           contentTitle: taskTitle,
//           htmlFormatContentTitle: true,
//         ),
//       );
//
//       const iosDetails = DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: false,
//         interruptionLevel: InterruptionLevel.timeSensitive,
//         categoryIdentifier: 'TASK_ALARM',
//         threadIdentifier: 'task_alarms',
//       );
//
//       final notificationDetails = NotificationDetails(
//         android: androidDetails,
//         iOS: iosDetails,
//       );
//
//       await _localNotificationsPlugin.show(
//         message.hashCode,
//         'Task Alarm',
//         notificationContent,
//         notificationDetails,
//         payload: jsonEncode({
//           ...message.data,
//           'action': 'task_alarm',
//         }),
//       );
//     } catch (e, stackTrace) {
//       print('❌ Failed to show alarm notification: $e\n$stackTrace');
//     }
//   }
//
//   void _handleNotificationTap(String? payload) {
//     try {
//       if (payload == null) {
//         Get.to(() => NotificationScreen());
//         return;
//       }
//
//       final data = jsonDecode(payload);
//       print('Notification tap data: $data');
//
//       if (data['action'] == 'task_alarm') {
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
//     audioPlayer.release();
//   }
// }

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
// import '../controller/alarm_controller.dart';
// import '../screens/alarm_screen.dart';
// import '../screens/notifications_screen.dart';
// import './api_service.dart';
// import '../models/notification_model.dart';
// import './alarm_service.dart';
// import 'package:timezone/data/latest.dart' as tz;
//
// @pragma('vm:entry-point')
// class NotificationFirebaseService {
//   final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
//   final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   bool _permissionRequested = false;
//   final ApiService _apiService = ApiService();
//   static bool _hasUnreadNotifications = false;
//   final AlarmService _alarmService = AlarmService();
//
//   static final NotificationFirebaseService _instance = NotificationFirebaseService._internal();
//   factory NotificationFirebaseService() => _instance;
//   NotificationFirebaseService._internal() {
//     initialize();
//     print('[Flutter] Initialized NotificationFirebaseService at ${DateTime.now()}');
//   }
//
//   static final FlutterLocalNotificationsPlugin _localNotificationsPlugins = FlutterLocalNotificationsPlugin();
//   static final AlarmService _alarmServices = AlarmService();
//
//   @pragma('vm:entry-point')
//   static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//     try {
//       debugPrint('📩 Background Notification from firebase_service: ${message.data['title'] ?? 'No title'}');
//       debugPrint('📩 Background Notification from firebase_service: ${message.notification?.title}');
//       // Initialize Firebase
//       await Firebase.initializeApp();
//
//       // Initialize timezone
//       tz.initializeTimeZones();
//       tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
//
//       // Initialize notifications
//       const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//       const iosSettings = DarwinInitializationSettings();
//       const initializationSettings = InitializationSettings(
//         android: androidSettings,
//         iOS: iosSettings,
//       );
//       await _localNotificationsPlugins.initialize(initializationSettings);
//
//       // Create notification channel
//       const androidChannel = AndroidNotificationChannel(
//         'high_importance_channel',
//         'High Importance Notifications',
//         description: 'Used for important notifications',
//         importance: Importance.max,
//         playSound: true,
//         enableLights: true,
//         enableVibration: true,
//         showBadge: true,
//         audioAttributesUsage: AudioAttributesUsage.notification,
//       );
//       final androidPlugin = _localNotificationsPlugins
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
//       await androidPlugin?.createNotificationChannel(androidChannel);
//
//       // Initialize AlarmService
//       await _alarmServices.initialize();
//
//       // Process notification
//       await showLocalNotification(message.data);
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error in background handler: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> initialize() async {
//     try {
//       print('[Flutter] Initializing NotificationFirebaseService...');
//
//       // Initialize AlarmService
//       await _alarmService.initialize();
//
//       // Request notification and alarm permissions
//       // await requestNotificationPermission();
//
//       // Initialize local notifications
//       await _initializeLocalNotifications();
//
//       // Set up token refresh listener
//       _setupTokenRefreshListener();
//
//       // Configure FCM listeners
//       await _configureFcmListeners();
//
//       print('[Flutter] NotificationFirebaseService initialized successfully');
//     } catch (e, stackTrace) {
//       debugPrint('❌ Notification initialization failed: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> requestNotificationPermission() async {
//     if (_permissionRequested) return;
//     _permissionRequested = true;
//
//     try {
//       // Request notification permissions
//       final settings = await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//         announcement: false,
//         criticalAlert: false,
//         provisional: false,
//       );
//
//       if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//         debugPrint('✅ Notification permission granted.');
//       } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
//         debugPrint('⚠️ Provisional permission granted.');
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
//
//       // Request SCHEDULE_EXACT_ALARM for Android 12+
//       if (Platform.isAndroid) {
//         final status = await Permission.scheduleExactAlarm.status;
//         if (!status.isGranted) {
//           final result = await Permission.scheduleExactAlarm.request();
//           if (!result.isGranted) {
//             debugPrint('❌ SCHEDULE_EXACT_ALARM permission denied.');
//             Get.snackbar(
//               'Alarm Permission',
//               'Please enable exact alarm permission for background alarms.',
//               snackPosition: SnackPosition.BOTTOM,
//               duration: const Duration(seconds: 4),
//               onTap: (_) => AppSettings.openAppSettings(type: AppSettingsType.settings),
//             );
//           }
//         }
//
//         // Request POST_NOTIFICATIONS for Android 13+
//         final notificationStatus = await Permission.notification.status;
//         if (!notificationStatus.isGranted) {
//           await Permission.notification.request();
//         }
//
//         // Request battery optimization exemption
//         final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
//         if (!batteryStatus.isGranted) {
//           await Permission.ignoreBatteryOptimizations.request();
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ Error requesting permissions: $e');
//     }
//   }
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
//
//     const androidChannel = AndroidNotificationChannel(
//       'alarm_channel',
//       'Alarm Notifications',
//       description: 'Notifications for alarm triggers',
//       importance: Importance.max,
//       playSound: false,
//       enableLights: true,
//       enableVibration: true,
//       showBadge: true,
//       audioAttributesUsage: AudioAttributesUsage.alarm,
//     );
//
//     const taskAlarmsChannel = AndroidNotificationChannel(
//       'task_alarms',
//       'Task Alarms',
//       description: 'High priority notifications for task alarms',
//       importance: Importance.max,
//       playSound: false,
//       enableVibration: true,
//       enableLights: true,
//       showBadge: true,
//     );
//
//     final androidPlugin = _localNotificationsPlugin
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
//
//     try {
//       print('[Flutter] Creating notification channels');
//       await androidPlugin?.createNotificationChannel(androidChannel);
//       await androidPlugin?.createNotificationChannel(taskAlarmsChannel);
//       print('[Flutter] Notification channels created successfully');
//     } catch (e, stackTrace) {
//       print('[Flutter] Error creating notification channels: $e\n$stackTrace');
//     }
//
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
//
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
//       FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
//       FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
//       final initialMessage = await _messaging.getInitialMessage();
//       if (initialMessage != null) {
//         _handleBackgroundMessage(initialMessage);
//       }
//       FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error configuring FCM listeners: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     try {
//       print('📱 Handling foreground message: ${message.messageId}');
//       print('📱 Message data: ${message.data}');
//       print('📱 Notification: ${message.notification?.title} - ${message.notification?.body}');
//
//       final bool isAlarm = message.data['type'] == 'set_alarm' ||
//           (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
//
//       if (message.data.isNotEmpty) {
//         await showLocalNotification(message.data);
//       }
//
//       // await showLocalNotification(message.data);
//
//       // if (isAlarm) {
//       //   await _showAlarmNotification(message);
//       //   // await _scheduleAlarmFromMessage(message.data);
//       // } else {
//       //   await showLocalNotification(message.data);
//       // }
//     } catch (e, stackTrace) {
//       print('❌ Error handling foreground message: $e\n$stackTrace');
//     }
//   }
//
//   Future<void> _handleBackgroundMessage(RemoteMessage message) async {
//     try {
//       print('📱 Handling background message: ${message.messageId}');
//       print('📱 Message data: ${message.data}');
//       print('📱 Notification: ${message.notification?.title} - ${message.notification?.body}');
//
//       final bool isAlarm = message.data['type'] == 'task_alarm' ||
//           (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
//
//
//       if (message.data.isNotEmpty) {
//         await showLocalNotification(message.data);
//       }
//       // if (isAlarm) {
//       //   await _showAlarmNotification(message);
//       //   await _scheduleAlarmFromMessage(message.data);
//       // } else {
//       //   await showLocalNotification(message.data);
//       // }
//     } catch (e, stackTrace) {
//       print('❌ Error handling background message: $e\n$stackTrace');
//     }
//   }
//
//
//
//   // @pragma('vm:entry-point')
//   // static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   //   debugPrint('📩 Background Notification from firebase_service: ${message.notification?.title}');
//   //   try {
//   //     WidgetsFlutterBinding.ensureInitialized();
//   //     await Firebase.initializeApp();
//   //
//   //     final localNotificationsPlugin = FlutterLocalNotificationsPlugin();
//   //     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//   //     const iosSettings = DarwinInitializationSettings();
//   //     const initializationSettings = InitializationSettings(
//   //       android: androidSettings,
//   //       iOS: iosSettings,
//   //     );
//   //     await localNotificationsPlugin.initialize(initializationSettings);
//   //
//   //     const androidChannel = AndroidNotificationChannel(
//   //       'alarm_channel',
//   //       'Alarm Notifications',
//   //       description: 'Notifications for alarm triggers',
//   //       importance: Importance.max,
//   //       playSound: false,
//   //       enableLights: true,
//   //       enableVibration: true,
//   //       showBadge: true,
//   //       audioAttributesUsage: AudioAttributesUsage.alarm,
//   //     );
//   //     const taskAlarmsChannel = AndroidNotificationChannel(
//   //       'task_alarms',
//   //       'Task Alarms',
//   //       description: 'High priority notifications for task alarms',
//   //       importance: Importance.max,
//   //       playSound: false,
//   //       enableVibration: true,
//   //       enableLights: true,
//   //       showBadge: true,
//   //     );
//   //     final androidPlugin = localNotificationsPlugin
//   //         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
//   //     await androidPlugin?.createNotificationChannel(androidChannel);
//   //     await androidPlugin?.createNotificationChannel(taskAlarmsChannel);
//   //
//   //     final service = NotificationFirebaseService();
//   //     await service._alarmService.initialize();
//   //
//   //     final bool isAlarm = message.data['type'] == 'task_alarm' ||
//   //         (message.data.containsKey('task_id') && message.data.containsKey('alarm_id'));
//   //
//   //     await service.showLocalNotification(message.data);
//   //     // if (isAlarm) {
//   //     //   await service._showAlarmNotification(message);
//   //     //   // await service._scheduleAlarmFromMessage(message.data);
//   //     // } else {
//   //     //   await service.showLocalNotification(message.data);
//   //     // }
//   //   } catch (e, stackTrace) {
//   //     debugPrint('❌ Error in background handler: $e\n$stackTrace');
//   //   }
//   // }
//
//   // Future<void> _scheduleAlarmFromMessage(Map<String, dynamic> data) async {
//   //   try {
//   //     print('[Flutter] Scheduling alarm for task: ${data['task_id']}');
//   //     final taskId = data['task_id'] as String;
//   //     final alarmId = data['alarm_id'] as String;
//   //     final taskTitle = data['title'] as String;
//   //     final triggerTime = DateTime.parse(data['trigger_time']); // Parse ISO 8601
//   //     final tzTriggerTime = tz.TZDateTime.from(triggerTime, tz.local);
//   //
//   //     await _alarmService.setAlarm(
//   //       alarmTime: tzTriggerTime,
//   //       alarmId: alarmId,
//   //       taskId: taskId,
//   //       taskTitle: taskTitle,
//   //     );
//   //   } catch (e, stackTrace) {
//   //     print('[Flutter] Error scheduling alarm: $e\n$stackTrace');
//   //   }
//   // }
//
//
//   Future<void> _scheduleAlarmFromMessage(Map<String, dynamic> data) async {
//     try {
//       print('[Flutter] Scheduling alarm for task: ${data['task_id']}');
//       final taskId = data['task_id'] as String;
//       final alarmId = data['alarm_id'] as String;
//       final taskTitle = data['title'] as String;
//       final triggerTimeStr = data['trigger_time'] as String;
//
//       // Initialize timezone if not already done
//       try {
//         tz.local; // Check if initialized
//       } catch (e) {
//         print('[Flutter] Initializing timezone database');
//         tz.initializeTimeZones();
//         tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
//       }
//
//       // Parse trigger time
//       final triggerTime = DateTime.parse(triggerTimeStr); // Parse ISO 8601 (UTC)
//       final tzTriggerTime = tz.TZDateTime.from(triggerTime, tz.local); // Convert to IST
//
//       // Validate future time
//       final now = tz.TZDateTime.now(tz.local);
//       print("Now-------->$now");
//       if (tzTriggerTime.isBefore(now)) {
//         print('[Flutter] Warning: Alarm time $tzTriggerTime is in the past, scheduling for next day');
//         // Optionally adjust to next day
//         // tzTriggerTime = tzTriggerTime.add(Duration(days: 1));
//       }
//
//       print('[Flutter] Parsed trigger time: $tzTriggerTime (IST)');
//       await _alarmService.setAlarm(
//         alarmTime: tzTriggerTime,
//         alarmId: alarmId,
//         taskId: taskId,
//         taskTitle: taskTitle,
//       );
//     } catch (e, stackTrace) {
//       print('[Flutter] Error scheduling alarm: $e\n$stackTrace');
//       rethrow;
//     }
//   }
//
//   // Future<void> showLocalNotification(RemoteMessage message) async {
//   //   final notification = message.notification;
//   //   if (notification == null) return;
//   //
//   //   try {
//   //     const channelId = 'high_importance_channel';
//   //     const channel = AndroidNotificationChannel(
//   //       channelId,
//   //       'High Importance Notifications',
//   //       description: 'Used for important notifications',
//   //       importance: Importance.max,
//   //       playSound: true,
//   //       showBadge: true,
//   //     );
//   //
//   //     await _localNotificationsPlugin
//   //         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//   //         ?.createNotificationChannel(channel);
//   //
//   //     final androidDetails = AndroidNotificationDetails(
//   //       channel.id,
//   //       channel.name,
//   //       channelDescription: channel.description,
//   //       importance: Importance.max,
//   //       priority: Priority.max,
//   //       playSound: true,
//   //       ticker: 'ticker',
//   //       visibility: NotificationVisibility.public,
//   //       enableVibration: true,
//   //       enableLights: true,
//   //       color: const Color(0xFF2196F3),
//   //       ledColor: const Color(0xFF2196F3),
//   //       ledOnMs: 1000,
//   //       ledOffMs: 500,
//   //     );
//   //
//   //     const iosDetails = DarwinNotificationDetails(
//   //       presentAlert: true,
//   //       presentBadge: true,
//   //       presentSound: true,
//   //     );
//   //
//   //     final notificationDetails = NotificationDetails(
//   //       android: androidDetails,
//   //       iOS: iosDetails,
//   //     );
//   //
//   //     await _localNotificationsPlugin.show(
//   //       notification.hashCode,
//   //       notification.title,
//   //       notification.body,
//   //       notificationDetails,
//   //       payload: jsonEncode(message.data),
//   //     );
//   //   } catch (e, stackTrace) {
//   //     debugPrint('❌ Failed to show local notification: $e\n$stackTrace');
//   //   }
//   // }
//
//   static Future<void> showLocalNotification(Map<String, dynamic> data) async {
//     try {
//       final type = data['type'];
//       if (type != 'task_created') {
//         print('Skipping notification for type: $type');
//         return;
//       }
//
//       final taskId = data['task_id'] ?? 'unknown';
//       final title = data['title'] ?? 'New Task';
//       final message = data['notification_body'] ?? 'You have a new task assigned';
//
//       if (data.containsKey('alarm_settings')) {
//         try {
//           final alarmSettings = data['alarm_settings'] is String
//               ? jsonDecode(data['alarm_settings'])
//               : data['alarm_settings'];
//
//           final alarmId = alarmSettings['alarm_id']?.toString();
//           final startDate = alarmSettings['start_date'];
//           final startTime = alarmSettings['start_time'];
//           final frequency = alarmSettings['frequency'];
//
//           if (alarmId != null && startDate != null && startTime != null) {
//             print('Scheduling alarm for task: $taskId');
//             print('Alarm settings: $alarmSettings');
//
//             String formattedStartTime = startTime;
//             if (startTime.split(':').length == 2) {
//               formattedStartTime = '$startTime:00';
//             }
//             final alarmDateTime = DateTime.parse('$startDate $formattedStartTime');
//             tz.TZDateTime alarmTime = tz.TZDateTime.from(alarmDateTime, tz.local);
//
//             final now = tz.TZDateTime.now(tz.local);
//             if (alarmTime.isBefore(now)) {
//               print('Alarm time in past, setting to now + 30s');
//               alarmTime = now.add(Duration(seconds: 30));
//             }
//
//             await _alarmServices.setAlarm(
//               alarmTime: alarmTime,
//               alarmId: alarmId,
//               taskId: taskId,
//               taskTitle: title,
//             );
//             print('Alarm scheduled for $alarmTime (Task: $title, ID: $taskId, Alarm ID: $alarmId)');
//           } else {
//             print('Missing alarm settings fields: $alarmSettings');
//           }
//         } catch (e) {
//           print('Error parsing alarm_settings: $e');
//         }
//       } else {
//         print('No alarm_settings in payload');
//       }
//
//       try {
//         const channelId = 'high_importance_channel';
//         const channel = AndroidNotificationChannel(
//           channelId,
//           'High Importance Notifications',
//           description: 'Used for important notifications',
//           importance: Importance.max,
//           playSound: true,
//           showBadge: true,
//         );
//
//         await _localNotificationsPlugins
//             .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//             ?.createNotificationChannel(channel);
//
//         final androidDetails = AndroidNotificationDetails(
//           channel.id,
//           channel.name,
//           channelDescription: channel.description,
//           importance: Importance.max,
//           priority: Priority.max,
//           playSound: true,
//           ticker: 'ticker',
//           visibility: NotificationVisibility.public,
//           enableVibration: true,
//           enableLights: true,
//           color: const Color(0xFF2196F3),
//           ledColor: const Color(0xFF2196F3),
//           ledOnMs: 1000,
//           ledOffMs: 500,
//         );
//
//         const iosDetails = DarwinNotificationDetails(
//           presentAlert: true,
//           presentBadge: true,
//           presentSound: true,
//         );
//
//         final notificationDetails = NotificationDetails(
//           android: androidDetails,
//           iOS: iosDetails,
//         );
//
//         await _localNotificationsPlugins.show(
//           taskId.hashCode,
//           title,
//           message,
//           notificationDetails,
//           payload: jsonEncode(data),
//         );
//         print('Local notification shown: $title');
//       } catch (e, stackTrace) {
//         debugPrint('❌ Failed to show local notification: $e\n$stackTrace');
//       }
//     } catch (e) {
//       print('Error showing local notification: $e');
//     }
//   }
//
//   Future<void> _showAlarmNotification(RemoteMessage message) async {
//     try {
//       const channelId = 'task_alarms';
//       const channel = AndroidNotificationChannel(
//         channelId,
//         'Task Alarms',
//         description: 'High priority notifications for task alarms',
//         importance: Importance.max,
//         playSound: false,
//         enableVibration: true,
//         enableLights: true,
//         showBadge: true,
//       );
//
//       await _localNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//
//       final taskTitle = message.data['title'] ?? 'Task Alarm';
//       final assignedBy = message.data['assigned_by'] ?? 'Unknown';
//       final deadline = message.data['deadline'] ?? '';
//
//       final notificationContent = '''
// Task: $taskTitle
// Assigned by: $assignedBy
// Deadline: $deadline
// ''';
//
//       final androidDetails = AndroidNotificationDetails(
//         channel.id,
//         channel.name,
//         channelDescription: channel.description,
//         importance: Importance.max,
//         priority: Priority.high,
//         visibility: NotificationVisibility.public,
//         playSound: false,
//         enableVibration: true,
//         enableLights: true,
//         color: const Color(0xFF2196F3),
//         ledColor: const Color(0xFF2196F3),
//         ledOnMs: 1000,
//         ledOffMs: 500,
//         styleInformation: BigTextStyleInformation(
//           notificationContent,
//           htmlFormatBigText: true,
//           contentTitle: taskTitle,
//           htmlFormatContentTitle: true,
//         ),
//       );
//
//       const iosDetails = DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: false,
//         interruptionLevel: InterruptionLevel.timeSensitive,
//         categoryIdentifier: 'TASK_ALARM',
//         threadIdentifier: 'task_alarms',
//       );
//
//       final notificationDetails = NotificationDetails(
//         android: androidDetails,
//         iOS: iosDetails,
//       );
//
//       await _localNotificationsPlugin.show(
//         message.hashCode,
//         'Task Alarm',
//         notificationContent,
//         notificationDetails,
//         payload: jsonEncode({
//           ...message.data,
//           'action': 'set_alarm',
//         }),
//       );
//     } catch (e, stackTrace) {
//       print('❌ Failed to show alarm notification: $e\n$stackTrace');
//     }
//   }
//
//   void _handleNotificationTap(String? payload) {
//     try {
//       if (payload == null) {
//         Get.to(() => NotificationScreen());
//         return;
//       }
//
//       final data = jsonDecode(payload);
//       print('Notification tap data: $data');
//
//       if (data['action'] == 'task_alarm') {
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
//     // No need to release AlarmService, as it's a singleton
//   }
// }


import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../screens/notifications_screen.dart';
import './api_service.dart';
import '../models/notification_model.dart';
import './alarm_service.dart';

@pragma('vm:entry-point')
class NotificationFirebaseService {
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _permissionRequested = false;
  final ApiService _apiService = ApiService();
  static bool _hasUnreadNotifications = false;
  final AlarmService _alarmService = AlarmService();
  static const String _alarmsKey = 'pending_alarms';

  static final NotificationFirebaseService _instance = NotificationFirebaseService._internal();
  factory NotificationFirebaseService() => _instance;
  NotificationFirebaseService._internal() {
    initialize();
    print('[Flutter] Initialized NotificationFirebaseService at ${DateTime.now()}');
  }

  // @pragma('vm:entry-point')
  // static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  //   try {
  //     debugPrint('📩 Background Notification: ${message.data['title'] ?? 'No title'}');
  //     debugPrint('Message data: ${jsonEncode(message.data)}');
  //     await Firebase.initializeApp();
  //     tz.initializeTimeZones();
  //     tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  //     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  //     const iosSettings = DarwinInitializationSettings();
  //     const initializationSettings = InitializationSettings(
  //       android: androidSettings,
  //       iOS: iosSettings,
  //     );
  //     await FlutterLocalNotificationsPlugin().initialize(initializationSettings);
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
  //     final androidPlugin = FlutterLocalNotificationsPlugin()
  //         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  //     await androidPlugin?.createNotificationChannel(androidChannel);
  //     await AlarmService().initialize();
  //     await showLocalNotification(message.data);
  //   } catch (e, stackTrace) {
  //     debugPrint('❌ Error in background handler: $e\n$stackTrace');
  //   }
  // }


  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    try {
      debugPrint('📩 Background Notification START: ${message.data['title'] ?? 'No title'}');
      debugPrint('Message data: ${jsonEncode(message.data)}');
      await Firebase.initializeApp();
      debugPrint('Firebase initialized');
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint('Timezone initialized');
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await localNotifications.initialize(initializationSettings);
      debugPrint('Local notifications initialized');
      const androidChannel = AndroidNotificationChannel(
        'task_alarms',
        'Task Alarms',
        description: 'High priority notifications for task alarms',
        importance: Importance.max,
        playSound: true,
        enableLights: true,
        enableVibration: true,
        showBadge: true
      );
      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(androidChannel);
      debugPrint('Notification channel created');
      final alarmService = AlarmService();
      await alarmService.initialize();
      debugPrint('AlarmService initialized');
      await showLocalNotification(message.data);
      debugPrint('📩 Background Notification END: ${message.data['title'] ?? 'No title'}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error in background handler: $e\n$stackTrace');
    } finally {
      // Ensure resources are closed
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.commit();
        debugPrint('SharedPreferences committed');
      } catch (e) {
        debugPrint('❌ Error committing SharedPreferences: $e');
      }
    }
  }

  Future<void> initialize() async {
    try {
      print('[Flutter] Initializing NotificationFirebaseService...');
      await _alarmService.initialize();
      await _initializeLocalNotifications();
      _setupTokenRefreshListener();
      await _configureFcmListeners();
      await _restoreAlarms();
      print('[Flutter] NotificationFirebaseService initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Notification initialization failed: $e\n$stackTrace');
    }
  }

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
      if (Platform.isAndroid) {
        final status = await Permission.scheduleExactAlarm.status;
        if (!status.isGranted) {
          await Permission.scheduleExactAlarm.request();
        }
        final notificationStatus = await Permission.notification.status;
        if (!notificationStatus.isGranted) {
          await Permission.notification.request();
        }
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        if (!batteryStatus.isGranted) {
          Get.snackbar(
            'Battery Optimization',
            'Disable battery optimization for reliable alarms.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 6),
            onTap: (_) => AppSettings.openAppSettings(type: AppSettingsType.settings),
          );
          await Permission.ignoreBatteryOptimizations.request();
          // Recheck after request
          if (!(await Permission.ignoreBatteryOptimizations.status).isGranted) {
            debugPrint('❌ Battery optimization still enabled.');
          }
        } else {
          debugPrint('✅ Battery optimization disabled.');
        }
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }
  }



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

  Future<void> _initializeLocalNotifications() async {
    print('[Flutter] Starting local notifications initialization');
    const androidChannel = AndroidNotificationChannel(
      'task_alarms',
      'Task Alarms',
      description: 'High priority notifications for task alarms',
      importance: Importance.max,
      playSound: true,
      enableLights: true,
      enableVibration: true,
      showBadge: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      print('[Flutter] Creating notification channel');
      await androidPlugin?.createNotificationChannel(androidChannel);
      print('[Flutter] Notification channel created successfully');
    } catch (e, stackTrace) {
      print('[Flutter] Error creating notification channel: $e\n$stackTrace');
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    try {
      print('[Flutter] Initializing FlutterLocalNotificationsPlugin');
      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          print('[Flutter] Notification response received: '
              'actionId=${response.actionId}, payload=${response.payload}, '
              'input=${response.input}');
          try {
            if (response.payload != null) {
              _handleNotificationTap(response.payload!);
            }
          } catch (e, stackTrace) {
            print('[Flutter] Error handling notification response: $e\n$stackTrace');
          }
        },
      );
      print('[Flutter] Local notifications initialized successfully');
    } catch (e, stackTrace) {
      print('[Flutter] Error initializing local notifications: $e\n$stackTrace');
    }
  }

  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 New FCM Token: $newToken');
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('username');
      if (currentUser != null) {
        await _apiService.updateFcmToken(currentUser, newToken);
      }
    }).onError((e) {
      debugPrint('❌ Error on token refresh: $e');
    });
  }

  Future<void> _configureFcmListeners() async {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 Foreground Notification: ${message.data['title'] ?? 'No title'}');
        debugPrint('Message data: ${jsonEncode(message.data)}');
        showLocalNotification(message.data);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 Handling background message tap: ${message.messageId}');
        print('📱 Message data: ${message.data}');
        _handleNotificationTap(jsonEncode(message.data));
      });
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('📱 Handling initial message: ${initialMessage.messageId}');
        _handleNotificationTap(jsonEncode(initialMessage.data));
      }
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e, stackTrace) {
      debugPrint('❌ Error configuring FCM listeners: $e\n$stackTrace');
    }
  }

  static Future<void> showLocalNotification(Map<String, dynamic> data) async {
    try {
      final type = data['type'];
      if (type != 'task_created' && type != 'set_alarm') {
        print('Skipping notification for type: $type');
        return;
      }

      final taskId = data['task_id'] ?? 'unknown';
      final alarmId = data['alarm_id'] ?? 'unknown';
      String title = data['title'] ?? 'New Task';
      String? message;
      tz.TZDateTime? alarmTime;

      if (type == 'task_created') {
        final creatorName = data['creator_name'] ?? 'Someone';
        final description = data['description'] ?? '';
        final status = data['status']?.toUpperCase() ?? 'UNKNOWN';
        title = 'Task Created: ${data['title'] ?? 'New Task'}';
        message = '$creatorName has created a new task: "${data['title'] ?? 'New Task'}". '
            'Description: $description. '
            'Status: $status. '
            'Please review in the Task Management App.';
        if (data.containsKey('alarm_settings')) {
          try {
            final alarmSettings = data['alarm_settings'] is String
                ? jsonDecode(data['alarm_settings'])
                : data['alarm_settings'];
            final startDate = alarmSettings['start_date'];
            final startTime = alarmSettings['start_time'];
            if (startDate != null && startTime != null) {
              print('Scheduling alarm for task: $taskId');
              print('Alarm settings: $alarmSettings');
              String formattedStartTime = startTime;
              if (startTime.split(':').length == 2) {
                formattedStartTime = '$startTime:00';
              }
              final alarmDateTime = DateTime.parse('$startDate $formattedStartTime');
              alarmTime = tz.TZDateTime.from(alarmDateTime, tz.local);
              final now = tz.TZDateTime.now(tz.local);
              if (alarmTime.isBefore(now)) {
                print('Alarm time in past, setting to now + 30s');
                alarmTime = now.add(Duration(seconds: 30));
              }
              await _persistAlarm({
                'alarm_id': alarmId,
                'task_id': taskId,
                'title': data['title'] ?? 'New Task',
                'trigger_time': alarmTime.toIso8601String(),
              });
            }
          } catch (e) {
            print('Error parsing alarm_settings: $e');
          }
        }
      } else if (type == 'set_alarm') {
        title = data['title'] ?? 'Task Alarm';
        message = data['description'] ?? 'Task alarm triggered!';
        final triggerTime = data['trigger_time'];
        if (triggerTime != null) {
          try {
            final triggerDateTime = DateTime.parse(triggerTime);
            alarmTime = tz.TZDateTime.from(triggerDateTime, tz.local);
            final now = tz.TZDateTime.now(tz.local);
            if (alarmTime.isBefore(now)) {
              print('Alarm time in past, setting to now + 30s');
              alarmTime = now.add(Duration(seconds: 30));
            }
            await _persistAlarm({
              'alarm_id': alarmId,
              'task_id': taskId,
              'title': data['title'] ?? 'Task Alarm',
              'trigger_time': alarmTime.toIso8601String(),
            });
          } catch (e) {
            print('Error parsing trigger_time: $e');
          }
        }
      }

      if (alarmTime != null) {
        await AlarmService().setAlarm(
          alarmTime: alarmTime,
          alarmId: alarmId,
          taskId: taskId,
          taskTitle: data['title'] ?? 'New Task',
        );
        print('Alarm scheduled for $alarmTime (Task: ${data['title'] ?? 'New Task'}, ID: $taskId, Alarm ID: $alarmId)');
      }

      if (message != null) {
        try {
          const channelId = 'task_alarms';
          const channel = AndroidNotificationChannel(
            channelId,
            'Task Alarms',
            description: 'High priority notifications for task alarms',
            importance: Importance.max,
            playSound: true,
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          );
          await FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(channel);
          final androidDetails = AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            ticker: 'ticker',
            visibility: NotificationVisibility.public,
            enableVibration: true,
            enableLights: true,
            color: const Color(0xFF2196F3),
            ledColor: const Color(0xFF2196F3),
            ledOnMs: 1000,
            ledOffMs: 500,
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
          await FlutterLocalNotificationsPlugin().show(
            taskId.hashCode,
            title,
            message,
            notificationDetails,
            payload: jsonEncode(data),
          );
          print('Local notification shown: $title');
        } catch (e, stackTrace) {
          debugPrint('❌ Error showing local notification: $e\n$stackTrace');
        }
      }
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  static Future<void> _persistAlarm(Map<String, dynamic> alarm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString(_alarmsKey) ?? '[]';
      final alarms = jsonDecode(alarmsJson) as List<dynamic>;
      alarms.removeWhere((a) => a['alarm_id'] == alarm['alarm_id']);
      alarms.add(alarm);
      await prefs.setString(_alarmsKey, jsonEncode(alarms));
      print('Persisted alarm: ${alarm['alarm_id']}');
    } catch (e) {
      print('Error persisting alarm: $e');
    }
  }

  static Future<void> _restoreAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString(_alarmsKey) ?? '[]';
      final alarms = jsonDecode(alarmsJson) as List<dynamic>;
      for (var alarm in alarms) {
        final alarmId = alarm['alarm_id'];
        final taskId = alarm['task_id'];
        final title = alarm['title'];
        final triggerTime = alarm['trigger_time'];
        if (triggerTime != null) {
          try {
            final triggerDateTime = DateTime.parse(triggerTime);
            tz.TZDateTime alarmTime = tz.TZDateTime.from(triggerDateTime, tz.local);
            final now = tz.TZDateTime.now(tz.local);
            if (alarmTime.isBefore(now)) {
              alarmTime = now.add(Duration(seconds: 30));
            }
            await AlarmService().setAlarm(
              alarmTime: alarmTime,
              alarmId: alarmId,
              taskId: taskId,
              taskTitle: title,
            );
            print('Restored alarm: $alarmId for task: $taskId');
          } catch (e) {
            print('Error restoring alarm: $e');
          }
        }
      }
    } catch (e) {
      print('Error restoring alarms: $e');
    }
  }

  void _handleNotificationTap(String payload) {
    try {
      final data = jsonDecode(payload);
      print('Notification tap data: $data');
      if (data['type'] == 'set_alarm') {
        // Get.to(() => AlarmScreen(
        //   taskId: data['task_id'] ?? '',
        //   alarmId: data['alarm_id'] ?? '',
        //   taskTitle: data['title'] ?? 'Task Alarm',
        //   assigneeName: data['assignee_name'] ?? '',
        //   assignedBy: data['assigned_by'] ?? 'Unknown',
        //   dueDate: data['deadline'] ?? '',
        // ));
      } else {
        Get.to(() => NotificationScreen());
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling notification tap: $e\n$stackTrace');
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

  void dispose() {
    // No disposal needed for singleton AlarmService
  }
}
