import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'firebase_options.dart';

import 'screens/sign_in_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/my_tasks_screen.dart';
import 'screens/assign_tasks_screen.dart';
import 'theme/colors.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print('📱 Handling a background message: ${message.messageId}');
  print('📱 Message data: ${message.data}');
  
  // Initialize notification service for sound
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Initialize alarm service
  final alarmService = AlarmService();
  await alarmService.initialize();
  
  // Play notification sound
  await notificationService.handleNewNotification();
}

void main() async {  // Made async to properly handle initialization
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Set up certificate bypass for development
    if (!kReleaseMode) {
      HttpOverrides.global = DevHttpOverrides();
      print('🔒 SSL certificate validation disabled for development');
    }
    
    print('🔄 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
    );
    print('✅ Firebase initialized successfully');
    
    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();
    print('✅ Notification service initialized');
    
    // Initialize alarm service
    final alarmService = AlarmService();
    await alarmService.initialize();
    print('✅ Alarm service initialized');
    
    // Request FCM permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,  // Used for high priority notifications like alarms
    );
    print('✅ FCM permissions requested');
    
    // Set FCM foreground notification options
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    print('✅ FCM foreground notification options set');
    
    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📱 Received foreground message');
      print('📱 Message data: ${message.data}');
      
      if (message.notification != null) {
        print('📱 Message notification: ${message.notification?.title}');
        // Play notification sound for foreground messages
        await notificationService.handleNewNotification();
      }
      
      // Special handling for alarm notifications
      if (message.data['type'] == 'task_alarm') {
        print('⏰ Received task alarm notification');
        await alarmService.triggerAlarm(message.data);
      }
    });
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('✅ Firebase background message handler set');
    
    // Initialize shared preferences
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    print('✅ SharedPreferences initialized, isLoggedIn: $isLoggedIn');
    
    // Initialize socket service
    final socketService = SocketService.instance;
    try {
      print('🔌 Initializing socket service...');
      // Use secure WebSocket with SSL
      socketService.init('wss://134.209.149.12'); // Changed from http to wss
      
      // Get current user and register with socket
      final username = prefs.getString('username');
      if (username != null) {
        print('🔌 Connecting socket for user: $username');
        socketService.connect(username);
      }
      print('✅ Socket service initialized');
    } catch (e) {
      print('❌ Error initializing socket service: $e');
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
    // Still try to run the app even if initialization failed
    runApp(MyApp(isLoggedIn: false));
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
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
  }

  void _updateLoginState(bool isLoggedIn) {
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Management',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
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
      
      home: _isLoggedIn ? const DashboardScreen() : SignInScreen(onLogin: () => _updateLoginState(true)),
      onGenerateRoute: (settings) {
        if (!_isLoggedIn) {
          return MaterialPageRoute(
            builder: (context) => SignInScreen(onLogin: () => _updateLoginState(true)),
          );
        }
        
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (context) => const DashboardScreen());
          case '/my-tasks':
            return MaterialPageRoute(builder: (context) => const MyTasksScreen());
          case '/assign-tasks':
            return MaterialPageRoute(builder: (context) => const AssignTasksScreen());
          default:
            return MaterialPageRoute(builder: (context) => const DashboardScreen());
        }
      },
    );
  }
}
