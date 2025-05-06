import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';

//import '../screens/notification_screen.dart';
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

  /// Initializes the notification service, setting up permissions, local notifications,
  /// and listeners for all notification scenarios.
  Future<void> initialize() async {
    try {
      // Request notification permissions
      await _requestNotificationPermission();

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
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 New FCM Token: $newToken');
      // TODO: Send new token to your server for targeting notifications
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
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('❌ Error configuring FCM listeners: $e');
    }
  }

  /// Handles foreground notifications by displaying a local notification.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📩 Foreground Notification: ${message.notification?.title}');
    await _showLocalNotification(message);
  }

  /// Handles background/terminated notification taps, navigating to the appropriate screen.
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('📩 Background/Terminated Notification: ${message.notification?.title}');
    _handleNotificationTap(jsonEncode(message.data));
  }

  /// Background message handler (top-level function required by FCM).
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint('📩 Background Notification: ${message.notification?.title}');
    // Note: Local notifications in background require additional setup if needed
  }

  /// Displays a local notification for the given FCM message.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    try {
      const channelId = 'high_importance_channel';
      const channel = AndroidNotificationChannel(
        channelId,
        'High Importance Notifications',
        description: 'Used for important notifications',
        importance: Importance.high,
        playSound: true,
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
        ticker: 'ticker',
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

      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('❌ Failed to show local notification: $e');
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