import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:taskmanagement/services/api_service.dart';
import 'package:taskmanagement/services/notification_firebase_service.dart';
import 'dart:io';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'screens/sign_in_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/my_tasks_screen.dart';
import 'screens/assign_tasks_screen.dart';
import 'theme/colors.dart';

// Global variables for initialization state
bool _isFirebaseInitialized = false;
bool _isInitializing = false;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    print('📱 Background message handler started');
    print('📱 Message ID: ${message.messageId}');
    print('📱 Message data: ${message.data}');
    print('📱 Notification: ${message.notification?.title} - ${message.notification?.body}');

    if (!_isFirebaseInitialized && !_isInitializing) {
      print('🔄 Initializing Firebase in background handler...');
      _isInitializing = true;
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      _isFirebaseInitialized = true;
      _isInitializing = false;
      print('✅ Firebase initialized in background handler');
    }

    // Initialize services
    print('🔄 Initializing services in background handler...');
    final notificationService = NotificationService();
    await notificationService.initialize();
    print('✅ Notification service initialized in background handler');

    final alarmService = AlarmService();
    await alarmService.initialize();
    print('✅ Alarm service initialized in background handler');

    // Check if this is an alarm notification
    if (message.data['type'] == 'task_alarm') {
      print('⏰ Received task alarm notification in background');
      
      // Create notification details
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
      );

      final iosDetails = DarwinNotificationDetails(
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

      // Show the notification
      await alarmService.showAlarmNotification(
        title: 'Task Alarm',
        body: 'Time to complete your task!',
        payload: jsonEncode(message.data),
        notificationDetails: notificationDetails,
      );

      // Trigger the alarm
      await alarmService.triggerAlarm(message.data);
      print('✅ Alarm triggered in background');
    } else {
      print('📱 Handling regular notification in background');
      await notificationService.handleNewNotification();
      print('✅ Regular notification handled in background');
    }
  } catch (e) {
    print('❌ Error in background handler: $e');
    print('❌ Stack trace: ${StackTrace.current}');
    _isInitializing = false;
  }
}

Future<void> _initializeFirebase() async {
  if (_isFirebaseInitialized) {
    print('ℹ️ Firebase already initialized');
    return;
  }

  try {
    _isInitializing = true;
    print('🔄 Initializing Firebase...');

    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      print('ℹ️ Firebase already initialized (found existing apps)');
      _isFirebaseInitialized = true;
      return;
    }

    // Initialize Firebase if not already initialized
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    _isFirebaseInitialized = true;
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
    print('❌ Error stack trace: ${StackTrace.current}');
    // If we get a duplicate app error, consider it initialized
    if (e.toString().contains('duplicate-app')) {
      _isFirebaseInitialized = true;
      print('ℹ️ Firebase already initialized (duplicate app detected)');
    }
  } finally {
    _isInitializing = false;
  }
}

Future<void> ensureUserDataFromToken(SharedPreferences prefs) async {
  final token = prefs.getString('token') ?? prefs.getString('access_token');
  if (token == null) return;

  // Decode JWT (header.payload.signature)
  try {
    final parts = token.split('.');
    if (parts.length != 3) return;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final payloadMap = json.decode(payload);
    final userId = payloadMap['sub'] ?? payloadMap['user_id'];
    final username = payloadMap['username'];
    final role = payloadMap['role'];
    if ((prefs.getString('user_id') == null) && userId != null) {
      await prefs.setString('user_id', userId.toString());
      print('✅ Patched user_id from token: $userId');
    }
    if ((prefs.getString('username') == null) && username != null) {
      await prefs.setString('username', username);
      print('✅ Patched username from token: $username');
    }
    if ((prefs.getString('role') == null) && role != null) {
      await prefs.setString('role', role);
      print('✅ Patched role from token: $role');
    }
  } catch (e) {
    print('❌ Failed to decode user data from token: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Set up certificate bypass for development
    if (!kReleaseMode) {
      HttpOverrides.global = DevHttpOverrides();
      print('🔒 SSL certificate validation disabled for development');
    }

    // Initialize SharedPreferences first
    final prefs = await SharedPreferences.getInstance();
    Get.put(prefs); // Register SharedPreferences with Get
    print('✅ SharedPreferences initialized');

    // Patch user_id and username from token if missing
    await ensureUserDataFromToken(prefs);

    // Initialize Firebase
    await _initializeFirebase();

    // Initialize other services only if Firebase is initialized
    if (_isFirebaseInitialized) {
      // Initialize notification service
      final notificationService = NotificationService();
      await notificationService.initialize();
      print('✅ Notification service initialized');

      // Initialize Firebase notification service
      final nfbs = NotificationFirebaseService();
      await nfbs.initialize();
      print('✅ Firebase notification service initialized');

      // Initialize alarm service
      final alarmService = AlarmService();
      await alarmService.initialize();
      print('✅ Alarm service initialized');

      // Request FCM permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
      print('✅ FCM permissions requested');

      // Set FCM foreground notification options
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('✅ FCM foreground notification options set');

      // Set up foreground message handler
      // FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      //   print('📱 Received foreground message');
      //   print('📱 Message data: ${message.data}');
      //
      //   if (message.notification != null) {
      //     print('📱 Message notification: ${message.notification?.title}');
      //     await notificationService.handleNewNotification();
      //   }
      //
      //   if (message.data['type'] == 'task_alarm') {
      //     print('⏰ Received task alarm notification');
      //     await alarmService.triggerAlarm(message.data);
      //   }
      // });

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      print('✅ Firebase background message handler set');
    } else {
      print(
          '⚠️ Skipping Firebase-dependent services due to initialization failure');
    }

    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    print('✅ Login status: $isLoggedIn');

    // Initialize socket service
    final socketService = SocketService.instance;
    try {
      print('🔌 Initializing socket service...');
      const serverUrl = 'https://134.209.149.12';
      const wsUrl = 'wss://${ApiService.url}';
      // const wsUrl = 'wss://127.0.0.1:5001';
      socketService.init(wsUrl);

      final username = prefs.getString('username');
      if (username != null) {
        print('🔌 Connecting socket for user: $username');
        socketService.connect(username);
      }
      print('✅ Socket service initialized');
    } catch (e) {
      print('❌ Error initializing socket service: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
    }

    // Force portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(MyApp(isLoggedIn: isLoggedIn));
    print('✅ App started successfully');
  } catch (e, stackTrace) {
    print('❌ Error during initialization: $e');
    print('❌ Stack trace: $stackTrace');
  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, this.isLoggedIn = false}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'Task Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.accentCyan,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Inter',
        useMaterial3: true,

        // Configure global text theme
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontFamily: 'Inter',
          ),
          bodyMedium: TextStyle(
            color: AppColors.white,
            fontSize: 14,
            fontFamily: 'Inter',
          ),
        ),

        // Configure input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accentCyan),
          ),
          labelStyle: const TextStyle(color: AppColors.textGrey),
          hintStyle: const TextStyle(color: AppColors.textGrey),
        ),

        // Configure elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      home: _isLoggedIn
          ? const DashboardScreen()
          : SignInScreen(onLogin: () => _updateLoginState(true)),
      onGenerateRoute: (settings) {
        if (!_isLoggedIn) {
          return MaterialPageRoute(
            builder: (context) =>
                SignInScreen(onLogin: () => _updateLoginState(true)),
          );
        }

        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
                builder: (context) => const DashboardScreen());
          case '/my-tasks':
            return MaterialPageRoute(
                builder: (context) => const MyTasksScreen());
          case '/assign-tasks':
            return MaterialPageRoute(
                builder: (context) => const AssignTasksScreen());
          default:
            return MaterialPageRoute(
                builder: (context) => const DashboardScreen());
        }
      },
    );
  }

  void _updateLoginState(bool isLoggedIn) {
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }
}

