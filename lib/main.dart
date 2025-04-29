import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/socket_service.dart';

import 'screens/sign_in_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/colors.dart';

void main() async {  // Made async to properly handle initialization
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize socket service
  final socketService = SocketService.instance;
  socketService.init('http://134.209.149.12:5000');  // Updated to match your server IP
  
  // Get current user and register with socket
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username');
  if (username != null) {
    socketService.connect(username);
  }

  // Check if user is logged in
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MyApp({Key? key, this.isLoggedIn = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      
      // Use isLoggedIn to determine initial screen
      home: isLoggedIn ? const DashboardScreen() : const SignInScreen(),
    );
  }
}
