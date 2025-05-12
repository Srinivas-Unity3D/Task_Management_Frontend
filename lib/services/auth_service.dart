import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static const String _tokenKey = 'jwt_token';
  static const String _tokenExpiryKey = 'jwt_token_expiry';
  
  // Private constructor
  AuthService._internal();
  
  // Factory constructor
  factory AuthService() {
    return _instance;
  }

  // Get the stored token
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final expiryStr = prefs.getString(_tokenExpiryKey);
      
      // Check token expiry
      if (expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiry)) {
          await clearToken();
          return null;
        }
      }
      
      print('🔑 [Auth] Retrieved token: ${token != null ? '${token.substring(0, min(10, token.length))}...' : 'null'}');
      return token;
    } catch (e) {
      print('❌ [Auth] Error getting token: $e');
      return null;
    }
  }

  // Store the token
  Future<bool> setToken(String token) async {
    try {
      if (token.isEmpty) {
        print('❌ [Auth] Cannot store empty token');
        return false;
      }

      print('🔑 [Auth] Storing token: ${token.substring(0, min(10, token.length))}...');
      final prefs = await SharedPreferences.getInstance();
      
      // Set token expiry to 24 hours from now
      final expiry = DateTime.now().add(const Duration(hours: 24));
      await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
      
      return await prefs.setString(_tokenKey, token);
    } catch (e) {
      print('❌ [Auth] Error setting token: $e');
      return false;
    }
  }

  // Clear the token (for logout)
  Future<bool> clearToken() async {
    try {
      print('🔑 [Auth] Clearing token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenExpiryKey);
      return await prefs.remove(_tokenKey);
    } catch (e) {
      print('❌ [Auth] Error clearing token: $e');
      return false;
    }
  }

  // Check if user is logged in with valid token
  Future<bool> isLoggedIn() async {
    try {
      final token = await getToken();
      if (token == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      final expiryStr = prefs.getString(_tokenExpiryKey);
      if (expiryStr == null) return false;
      
      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      print('❌ [Auth] Error checking login status: $e');
      return false;
    }
  }
} 