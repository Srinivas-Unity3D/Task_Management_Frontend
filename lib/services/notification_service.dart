import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import './api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  NotificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _audioPlayer.setSource(AssetSource('sounds/notification.mp3'));
    _isInitialized = true;
  }

  Future<List<NotificationModel>> getNotifications() async {
    try {
      // Get the user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      print('Fetching notifications for user: $userId');
      print('API URL: ${ApiService.baseUrl}/notifications');

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('token')}',
          'user_id': userId ?? '',
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final notifications = data.map((json) => NotificationModel.fromJson(json)).toList();
        print('Successfully fetched ${notifications.length} notifications');
        return notifications;
      } else {
        print('Failed to load notifications. Status code: ${response.statusCode}');
        throw Exception('Failed to load notifications: ${response.body}');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      // For development, return mock data if API fails
      return [
        NotificationModel(
          id: '1',
          title: 'New Task Assignment',
          description: 'Project Alpha needs review',
          senderName: 'Durga',
          senderRole: 'Project Manager',
          timeAgo: '10m ago',
          type: 'task',
        ),
        NotificationModel(
          id: '2',
          title: 'Meeting Reminder',
          description: 'Team standup at 2 PM',
          senderName: 'Azim',
          senderRole: 'Admin',
          timeAgo: '1h ago',
          type: 'meeting',
        ),
        NotificationModel(
          id: '3',
          title: 'System Update',
          description: 'New features available',
          senderName: 'Ayan',
          senderRole: 'Developer',
          timeAgo: '2h ago',
          type: 'system',
        ),
      ];
    }
  }

  Future<void> markAsComplete(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      print('Marking notification $notificationId as complete for user: $userId');
      
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('token')}',
          'user_id': userId ?? '',
        },
        body: json.encode({
          'is_completed': true,
          'user_id': userId,
        }),
      );

      print('Mark complete response status: ${response.statusCode}');
      print('Mark complete response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as complete: ${response.body}');
      }
    } catch (e) {
      print('Error marking notification as complete: $e');
      throw Exception('Failed to mark notification as complete');
    }
  }

  Future<void> snoozeNotification(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      print('Snoozing notification $notificationId for user: $userId');
      
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/notifications/$notificationId/snooze'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('token')}',
          'user_id': userId ?? '',
        },
        body: json.encode({
          'user_id': userId,
          'snooze_duration': 30, // Snooze for 30 minutes by default
        }),
      );

      print('Snooze response status: ${response.statusCode}');
      print('Snooze response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to snooze notification: ${response.body}');
      }
    } catch (e) {
      print('Error snoozing notification: $e');
      throw Exception('Failed to snooze notification');
    }
  }

  Future<void> playNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setSource(AssetSource('sounds/notification.mp3'));
      await _audioPlayer.resume();
    } catch (e) {
      print('Error playing notification sound: $e');
    }
  }

  Future<void> vibrate() async {
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      print('Error during vibration: $e');
    }
  }

  Future<void> handleNewNotification() async {
    await playNotificationSound();
    await vibrate();
  }

  void dispose() {
    _audioPlayer.dispose();
    _isInitialized = false;
  }
} 