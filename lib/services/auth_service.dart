import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import './socket_service.dart';
import './audio_service.dart';
import './notification_state_service.dart';
import '../screens/sign_in_screen.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _socketService = SocketService.instance;
  final _audioService = AudioService();
  final _notificationState = NotificationStateService();
  bool _isLoggingOut = false;

  Future<void> login(String username) async {
    _socketService.setLoggedIn();
  }

  Future<void> logout(BuildContext context) async {
    if (_isLoggingOut) {
      print('⚠️ Logout already in progress');
      return;
    }

    _isLoggingOut = true;
    try {
      print('🔄 Starting logout process...');

      // Immediately disconnect socket and prevent reconnection
      _socketService.disconnect();
      
      // Clear notification state
      _notificationState.clearNotifications();

      // Clear SharedPreferences immediately
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {
        print('❌ Error clearing preferences: $e');
      }

      // Navigate to login screen immediately using PageRouteBuilder to prevent animations
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => SignInScreen(
              onLogin: () {
                // This callback won't be used in practice since we're logging out
                // but we need to provide it to satisfy the type system
              },
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
          (route) => false,
        );
      }

      // Cleanup remaining services in the background
      Future(() async {
        try {
          await _audioService.dispose();
        } catch (e) {
          print('❌ Error disposing audio service: $e');
        }
        print('✅ Logout cleanup completed');
      });
    } catch (e) {
      print('❌ Logout error: $e');
      // Try navigation even if there's an error
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => SignInScreen(
              onLogin: () {
                // This callback won't be used in practice since we're logging out
                // but we need to provide it to satisfy the type system
              },
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
          (route) => false,
        );
      }
    } finally {
      _isLoggingOut = false;
    }
  }
} 