import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:alarm/alarm.dart';
import '../models/task.dart';
import 'audio_service.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';

// Add SSL certificate handling
class AlarmHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();
  
  static const String baseUrl = 'https://134.209.149.12';
  final AudioService _audioService = AudioService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _vibrationTimer;
  bool _isInitialized = false;
  bool _isAlarmActive = false;
  String? _currentAlarmTaskId;
  
  // Replace instance callback with static callback
  // Define callback for alarm triggering
  static Function(Map<String, dynamic>)? _onAlarmTriggeredCallback;
  
  // Set the callback for when alarm is triggered
  static void setOnAlarmTriggeredCallback(Function(Map<String, dynamic>) callback) {
    _onAlarmTriggeredCallback = callback;
    print('✅ [AlarmService] onAlarmTriggered callback registered');
  }
  
  // Initialize the service
  Future<void> initialize() async {
    try {
      print('🔄 Initializing AlarmService...');
      
      // Initialize audio player
      await _audioService.initialize();
      print('✅ Audio service initialized');

      // Initialize notifications plugin
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _notificationsPlugin.initialize(initSettings);
      print('✅ Notifications plugin initialized');

      // Create high priority notification channel for alarms
      const androidChannel = AndroidNotificationChannel(
        'task_alarms',
        'Task Alarms',
        description: 'High priority notifications for task alarms',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        ledColor: Color(0xFF2196F3),
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        print('✅ Alarm notification channel created');
      }

      // Request notification permissions
      final settings = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
      print('📱 iOS notification permissions: $settings');

      // Initialize audio player with alarm sound
      await _audioService.setReleaseMode(ReleaseMode.loop);
      await _audioService.setVolume(1.0);
      await _audioService.setSource(AssetSource('sounds/alarm.mp3'));
      print('✅ Audio player initialized with alarm sound');

      _isInitialized = true;
      print('✅ AlarmService initialized successfully');
    } catch (e) {
      print('❌ Error initializing AlarmService: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
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
    if (!_isInitialized) {
      print('⏰ [AlarmService] Service not initialized, initializing now...');
      await initialize();
    }
    
    print('⏰ [AlarmService] Received alarm notification: $data');
    
    try {
      // Extract alarm data
      final String taskId = data['task_id'] ?? '';
      final String title = data['title'] ?? 'Task Alarm';
      final String body = data['body'] ?? 'Time to check your task';
      final bool isActive = data['is_active'] ?? true;
      final DateTime? nextTrigger = data['next_trigger'] != null 
          ? DateTime.parse(data['next_trigger']) 
          : null;
      
      if (taskId.isEmpty) {
        print('❌ [AlarmService] Invalid alarm data: missing task_id');
        return;
      }
      
      // Check if alarm is still active
      if (!isActive) {
        print('⏰ [AlarmService] Alarm is not active, skipping');
        return;
      }
      
      // Check if this is an immediate test alarm
      final bool isImmediate = data['immediate_alarm'] == 'true';
      if (isImmediate) {
        print('⏰ [AlarmService] IMMEDIATE ALARM detected! Playing alarm immediately');
        await triggerAlarm(data);
        return;
      }
      
      // Only proceed if this is a new alarm or a different alarm
      if (_isAlarmActive && _currentAlarmTaskId == taskId) {
        print('⏰ [AlarmService] Alarm already active for this task');
        return;
      }
      
      // Check if next trigger time is valid
      if (nextTrigger != null && nextTrigger.isBefore(DateTime.now())) {
        print('⏰ [AlarmService] Next trigger time is in the past, skipping');
        return;
      }
      
      // Trigger the alarm
      await triggerAlarm(data);
    } catch (e, stackTrace) {
      print('❌ [AlarmService] Error handling alarm notification: $e');
      print('❌ [AlarmService] Stack trace: $stackTrace');
    }
  }
  
  // Stop an active alarm
  Future<void> stopAlarm(String taskId) async {
    print('⏰ [AlarmService] Stopping alarm for task: $taskId');
    
    try {
      // Stop the alarm plugin's alarm
      await Alarm.stop(taskId.hashCode);
      print('⏰ [AlarmService] Alarm plugin alarm stopped');
      
      // Stop any audio
      await _audioService.stopAlarmSound();
      print('⏰ [AlarmService] Alarm sound stopped successfully');
    } catch (e) {
      print('❌ [AlarmService] Error stopping alarm sound: $e');
    }
    
    // Stop vibration
    _stopVibration();
    print('⏰ [AlarmService] Vibration stopped');
    
    // Cancel local notification
    try {
      await _notificationsPlugin.cancel(taskId.hashCode);
      print('⏰ [AlarmService] Notification canceled');
    } catch (e) {
      print('❌ [AlarmService] Error canceling notification: $e');
    }

    _isAlarmActive = false;
    _currentAlarmTaskId = null;
    
    print('⏰ [AlarmService] Alarm stopped for task: $taskId');
    
    // Acknowledge to the backend that the alarm was received and handled
    await _acknowledgeAlarm(taskId);
  }
  
  /// Trigger alarm from FCM notification data
  Future<void> triggerAlarm(Map<String, dynamic> data) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('🔔 Triggering alarm...');
      
      // Set alarm state
      _isAlarmActive = true;
      _currentAlarmTaskId = data['task_id']?.toString();
      
      // Play alarm sound with wake lock
      await _audioService.playAlarmSound();
      
      // Start vibration
      _vibrate();
      
      // Show high priority notification with full screen intent
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
        actions: [
          const AndroidNotificationAction('stop', 'Stop Alarm'),
        ],
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

      await _notificationsPlugin.show(
        _currentAlarmTaskId.hashCode,
        data['title'] ?? 'Task Alarm',
        data['body'] ?? 'Time to complete your task!',
        notificationDetails,
        payload: json.encode({
          'type': 'task_alarm',
          'task_id': _currentAlarmTaskId,
        }),
      );
      
      print('✅ Alarm triggered successfully');
    } catch (e) {
      print('❌ Error triggering alarm: $e');
      // Try to recover
      try {
        await _audioService.initialize();
        await _audioService.playAlarmSound();
      } catch (e) {
        print('❌ Error during recovery: $e');
      }
    }
  }
  
  void _vibrate() {
    // Cancel any existing vibration
    _stopVibration();
    // Start new vibration pattern
    _vibrationTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) {
      HapticFeedback.heavyImpact();
      Future.delayed(Duration(milliseconds: 500), () {
        HapticFeedback.heavyImpact();
      });
    });
    print('⏰ Vibration pattern started');
  }
  
  void _stopVibration() {
    if (_vibrationTimer != null) {
      _vibrationTimer!.cancel();
      _vibrationTimer = null;
      print('⏰ Vibration timer cancelled');
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
      final token = prefs.getString('access_token');
      
      if (token == null) {
        print('❌ [AlarmService] No access token available for alarm acknowledgment');
        return;
      }

      // Create the request payload
      final payload = {
        'alarm_id': _currentAlarmTaskId,
        'acknowledged_at': DateTime.now().toIso8601String(),
      };
      
      print('🔄 [AlarmService] Sending acknowledge request with payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/acknowledge_alarm'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );
      
      if (response.statusCode == 200) {
        print('✅ [AlarmService] Alarm acknowledged successfully');
        
        // Ensure all alarm state is cleaned up
        _isAlarmActive = false;
        _currentAlarmTaskId = null;
        await _audioService.stopAlarmSound();
        _stopVibration();
        
        // Force cancel all local notifications for this task
        await _notificationsPlugin.cancel(taskId.hashCode);
      } else {
        // Check for the specific "unknown column" error
        try {
          if (response.statusCode == 500 && 
              response.body.contains("Unknown column 'updated_by'")) {
            
            print('⚠️ [AlarmService] Detected updated_by column error, using direct alarm update endpoint');
            
            // Try a simpler approach - just update the alarm's status directly
            final directUpdateResponse = await http.post(
              Uri.parse('$baseUrl/alarms/deactivate'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: json.encode({
                'alarm_id': _currentAlarmTaskId,
                'task_id': taskId
              }),
            ).timeout(const Duration(seconds: 10));
            
            print('🔄 [AlarmService] Direct update response: ${directUpdateResponse.statusCode}');
            
            // Even if the direct update fails, clean up the alarm state locally
            _isAlarmActive = false;
            _currentAlarmTaskId = null;
            await _audioService.stopAlarmSound();
            _stopVibration();
            
            // Force cancel all local notifications for this task
            await _notificationsPlugin.cancel(taskId.hashCode);
            
            return;
          }
        } catch (e) {
          print('❌ [AlarmService] Error parsing response: $e');
        }
        
        print('❌ [AlarmService] Failed to acknowledge alarm: ${response.statusCode}');
        print('❌ [AlarmService] Error response: ${response.body}');
        
        // Clean up the alarm state locally anyway
        _isAlarmActive = false;
        _currentAlarmTaskId = null;
        await _audioService.stopAlarmSound();
        _stopVibration();
        
        // Force cancel all local notifications for this task
        await _notificationsPlugin.cancel(taskId.hashCode);
      }
    } catch (e) {
      print('❌ [AlarmService] Error acknowledging alarm: $e');
      
      // Clean up the alarm state locally anyway
      _isAlarmActive = false;
      _currentAlarmTaskId = null;
      await _audioService.stopAlarmSound();
      _stopVibration();
      
      // Force cancel all local notifications
      try {
        await _notificationsPlugin.cancel(taskId.hashCode);
      } catch (e) {
        print('❌ [AlarmService] Error canceling notification: $e');
      }
    }
  }

  // Set an alarm using the alarm plugin
  Future<void> setAlarm(DateTime dateTime, String taskId, String title, String body) async {
    print('⏰ [AlarmService] Setting alarm for task: $taskId at ${dateTime.toString()}');
    
    try {
      final alarmSettings = AlarmSettings(
        id: taskId.hashCode,
        dateTime: dateTime,
        assetAudioPath: 'assets/sounds/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: 'Stop',
          icon: '@mipmap/ic_launcher',
        ),
      );
      
      await Alarm.set(alarmSettings: alarmSettings);
      print('✅ [AlarmService] Alarm set successfully for task: $taskId');
    } catch (e) {
      print('❌ [AlarmService] Error setting alarm: $e');
      rethrow;
    }
  }

  // Cancel an alarm
  Future<void> cancelAlarm(String taskId) async {
    print('⏰ [AlarmService] Canceling alarm for task: $taskId');
    try {
      await Alarm.stop(taskId.hashCode);
      print('✅ [AlarmService] Alarm canceled successfully for task: $taskId');
    } catch (e) {
      print('❌ [AlarmService] Error canceling alarm: $e');
      rethrow;
    }
  }

  Future<void> showAlarmNotification({
    required String title,
    required String body,
    required String payload,
    required NotificationDetails notificationDetails,
  }) async {
    await _notificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
} 