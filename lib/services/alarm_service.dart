import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import 'audio_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();
  
  final AudioService _audioService = AudioService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _vibrationTimer;
  bool _isInitialized = false;
  bool _isAlarmActive = false;
  String? _currentAlarmTaskId;
  
  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    print('⏰ [AlarmService] Initializing...');
    
    // Initialize audio service
    await _audioService.initialize();
    
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
        
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    _isInitialized = true;
    print('⏰ [AlarmService] Initialized successfully');
  }
  
  void _onNotificationTapped(NotificationResponse response) {
    print('⏰ [AlarmService] Notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        // Parse the notification payload
        final Map<String, dynamic> payload = json.decode(response.payload!);
        
        // Stop the alarm
        if (payload['type'] == 'task_alarm') {
          stopAlarm(payload['task_id']);
        }
      } catch (e) {
        print('⏰ [AlarmService] Error parsing notification payload: $e');
        
        // Try to stop alarm using the raw payload if parsing fails
        stopAlarm(response.payload!);
      }
    }
  }
  
  // Handles an incoming alarm notification from FCM
  Future<void> handleAlarmNotification(Map<String, dynamic> data) async {
    if (!_isInitialized) await initialize();
    
    print('⏰ [AlarmService] Received alarm notification: $data');
    
    // Extract alarm data
    final String taskId = data['task_id'] ?? '';
    final String title = data['title'] ?? 'Task Alarm';
    final String body = data['body'] ?? 'Time to check your task';
    
    // Check if this is an immediate test alarm
    final bool isImmediate = data['immediate_alarm'] == 'true';
    if (isImmediate) {
      print('⏰ [AlarmService] IMMEDIATE ALARM detected! Playing alarm immediately');
      // For immediate alarms, always play even if another alarm is active
      await _triggerAlarm(taskId, title, body);
      return;
    }
    
    // Only proceed if this is a new alarm or a different alarm
    if (_isAlarmActive && _currentAlarmTaskId == taskId) {
      print('⏰ [AlarmService] Alarm already active for this task');
      return;
    }
    
    // Trigger the alarm
    await _triggerAlarm(taskId, title, body);
  }
  
  // Stop an active alarm
  Future<void> stopAlarm(String taskId) async {
    if (!_isAlarmActive || _currentAlarmTaskId != taskId) {
      print('⏰ [AlarmService] No active alarm to stop for task: $taskId');
      return;
    }
    
    await _audioService.stopAlarmSound();
    _stopVibration();
    
    _isAlarmActive = false;
    _currentAlarmTaskId = null;
    
    print('⏰ [AlarmService] Alarm stopped for task: $taskId');
    
    // Acknowledge to the backend that the alarm was received and handled
    await _acknowledgeAlarm(taskId);
  }
  
  // Trigger the alarm
  Future<void> _triggerAlarm(String taskId, String title, String body) async {
    print('⏰ [AlarmService] Triggering alarm for task: $taskId');
    
    _isAlarmActive = true;
    _currentAlarmTaskId = taskId;
    
    // Play alarm sound
    await _audioService.playAlarmSound();
    
    // Vibrate the phone
    _startVibrationPattern();
    
    // Show notification
    await _showAlarmNotification(taskId, title, body);
  }
  
  void _startVibrationPattern() {
    // Cancel any existing vibration
    _stopVibration();
    
    // Start new vibration pattern
    _vibrationTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) {
      HapticFeedback.heavyImpact();
      Future.delayed(Duration(milliseconds: 500), () {
        HapticFeedback.heavyImpact();
      });
    });
  }
  
  void _stopVibration() {
    if (_vibrationTimer != null) {
      _vibrationTimer!.cancel();
      _vibrationTimer = null;
    }
  }
  
  Future<void> _showAlarmNotification(String taskId, String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'task_alarms',
      'Task Alarms',
      channelDescription: 'Alarms for scheduled tasks',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm'),
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      enableVibration: true,
      color: Color.fromARGB(255, 125, 249, 255),
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    final payload = json.encode({
      'type': 'task_alarm',
      'task_id': taskId,
    });
    
    await _notificationsPlugin.show(
      taskId.hashCode,
      'Task Alarm: $title',
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
  
  // Acknowledge to the backend that the alarm was received and handled
  Future<void> _acknowledgeAlarm(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = 'http://134.209.149.12:5001'; // Get this from your API service
      
      final response = await http.post(
        Uri.parse('$baseUrl/alarms/acknowledge'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'task_id': taskId,
          'user_id': prefs.getString('user_id'),
          'acknowledged_at': DateTime.now().toIso8601String(),
        }),
      );
      
      if (response.statusCode == 200) {
        print('⏰ [AlarmService] Alarm acknowledgment sent successfully');
      } else {
        print('⏰ [AlarmService] Failed to send alarm acknowledgment: ${response.statusCode}');
      }
    } catch (e) {
      print('⏰ [AlarmService] Error acknowledging alarm: $e');
    }
  }
} 