import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';

import 'screens/sign_in_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/my_tasks_screen.dart';
import 'screens/assign_tasks_screen.dart';
import 'theme/colors.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // Initialize notification service for sound
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Initialize alarm service
  final alarmService = AlarmService();
  await alarmService.initialize();
  
  // Play notification sound
  await notificationService.handleNewNotification();
  
  print('Handling a background message: ${message.messageId}');
}

void main() async {  // Made async to properly handle initialization
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Initialize alarm service
  final alarmService = AlarmService();
  await alarmService.initialize();
  
  // Set up foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      // Play notification sound for foreground messages
      await notificationService.handleNewNotification();
    }
  });
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // Initialize socket service
  final socketService = SocketService.instance;
  try {
    print('🔌 Initializing socket service...');
    socketService.init('http://134.209.149.12:5001');  // Your server URL
    
    // Get current user and register with socket
    final username = prefs.getString('username');
    if (username != null) {
      print('🔌 Connecting socket for user: $username');
      socketService.connect(username);
    }
  } catch (e) {
    print('❌ Error initializing socket service: $e');
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
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
