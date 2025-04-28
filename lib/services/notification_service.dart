import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import './api_service.dart';

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
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => NotificationModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      // For development, return mock data if API fails
      print('Error fetching notifications, using mock data: $e');
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
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'is_completed': true}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as complete');
      }
    } catch (e) {
      print('Error marking notification as complete: $e');
      throw Exception('Failed to mark notification as complete');
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