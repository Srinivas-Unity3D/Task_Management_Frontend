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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');
      
      print('Fetching notifications for user: $userId, username: $username');

      if (userId == null || username == null) {
        throw Exception('User not logged in');
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Notifications response status: ${response.statusCode}');
      print('Notifications response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          print('Received ${notifications.length} notifications from server');
          
          return notifications.map((json) {
            try {
              return NotificationModel(
                id: json['id'] ?? '',
                title: json['title'] ?? '',
                description: json['description'] ?? '',
                senderName: json['sender_name'] ?? '',
                senderRole: json['sender_role'] ?? '',
                timeAgo: _getTimeAgo(json['created_at'] ?? DateTime.now().toIso8601String()),
                type: _getNotificationType(json['type'] ?? json['priority'] ?? ''),
                isCompleted: json['is_read'] == 1,
              );
            } catch (e) {
              print('Error parsing notification: $e');
              print('Problematic JSON: $json');
              rethrow;
            }
          }).toList();
        } else {
          print('Invalid response format: $responseData');
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 404) {
        print('User not found or no notifications available');
        return [];
      } else {
        print('Failed to load notifications. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      // Return empty list instead of mock data
      return [];
    }
  }

  String _getTimeAgo(String timestamp) {
    try {
      final DateTime time = DateTime.parse(timestamp);
      final Duration difference = DateTime.now().difference(time);
      
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return '';
    }
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

  Future<void> markAsComplete(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');

      if (userId == null || username == null) {
        throw Exception('User not logged in');
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/notifications/mark_read/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Mark complete response status: ${response.statusCode}');
      print('Mark complete response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as complete');
      }
    } catch (e) {
      print('Error marking notification as complete: $e');
      throw Exception('Failed to mark notification as complete');
    }
  }

  Future<void> snoozeNotification(String notificationId, DateTime snoozeUntil, {String? reason, String? audioNote}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');

      if (userId == null || username == null) {
        throw Exception('User not logged in');
      }

      // First, get the task ID from the notification
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          final notification = notifications.firstWhere(
            (n) => n['id'] == notificationId,
            orElse: () => throw Exception('Notification not found')
          );

          final taskId = notification['task_id'];
          if (taskId == null) {
            throw Exception('Task ID not found in notification');
          }

          // Snooze the notification
          final snoozeResponse = await http.post(
            Uri.parse('${ApiService.baseUrl}/notifications/snooze'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'notification_id': notificationId,
              'snooze_until': snoozeUntil.toIso8601String(),
              'reason': reason,
              'audio_note': audioNote
            }),
          );

          print('Snooze response status: ${snoozeResponse.statusCode}');
          print('Snooze response body: ${snoozeResponse.body}');

          if (snoozeResponse.statusCode == 200) {
            // Mark the notification as read to clear it from the notification bar
            await markAsComplete(notificationId);
            
            // Update the task status to snoozed
            final taskResponse = await http.put(
              Uri.parse('${ApiService.baseUrl}/tasks/$taskId'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: json.encode({
                'status': 'snoozed',
                'updated_by': username,
                'snooze_until': snoozeUntil.toIso8601String(),
                'snooze_reason': reason
              }),
            );

            if (taskResponse.statusCode != 200) {
              print('Failed to update task status to snoozed');
            }
          } else {
            final errorBody = json.decode(snoozeResponse.body);
            final errorMessage = errorBody['message'] ?? 'Failed to snooze notification';
            throw Exception(errorMessage);
          }
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to fetch notifications');
      }
    } catch (e) {
      print('Error snoozing notification: $e');
      rethrow;
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