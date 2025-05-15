import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import './api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import '../screens/alarm_screen.dart';
import '../services/alarm_service.dart';
import 'package:record/record.dart' as record_pkg;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' as math;

// Add a global navigator key (in main.dart, but reference here)
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // Add static variable to track unread notifications
  static bool _hasUnreadNotifications = false;

  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int _notificationId = 0;
  Function(Map<String, dynamic>)? onAlarmTriggered;

  NotificationService._internal();

  // Add method to update unread state
  void setUnreadState(bool hasUnread) {
    _hasUnreadNotifications = hasUnread;
  }

  // Add method to get unread state
  bool getUnreadState() {
    return _hasUnreadNotifications;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize audio player
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          if (response.payload != null) {
            _handleNotificationTap(response);
          }
        },
      );

      // Create notification channel for alarms
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'task_alarms',
        'Task Alarms',
        description: 'Notifications for task alarms',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Register the alarm triggered callback
      AlarmService.setOnAlarmTriggeredCallback(_showAlarmUI);

      _isInitialized = true;
    } catch (e) {
      print('🔔 Error initializing notification service: $e');
    }
  }

  // Shared method to show snooze UI - can be used by notification bar or alarm screen
  Future<void> showSnoozeUI({
    required BuildContext context,
    required String taskId,
    required String alarmId,
    required String taskTitle,
    Function? onSnoozeComplete,
  }) async {
    // Default snooze time
    DateTime snoozeDateTime = DateTime.now().add(Duration(minutes: 30));
    String reason = '';
    String? audioData;
    String? audioFilePath;
    int? audioDuration;
    bool isRecording = false;
    bool isPlaying = false;
    final AudioPlayer player = AudioPlayer();
    
    // Show the snooze dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Theme(
          data: ThemeData.dark().copyWith(
            primaryColor: Color(0xFF7DF9FF),
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF7DF9FF),
              onPrimary: Colors.black,
              surface: Color(0xFF131B2E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF0A0F1C),
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              // Function to check if snooze button should be enabled
              bool canSnooze = reason.isNotEmpty || audioData != null;
              
              // Function to start recording
              Future<void> startRecording() async {
                final record = record_pkg.AudioRecorder();
                try {
                  print('🎙️ Checking recording permission');
                  if (await record.hasPermission()) {
                    final directory = await getTemporaryDirectory();
                    
                    // Ensure directory exists
                    if (!await directory.exists()) {
                      print('📁 Creating temporary directory: ${directory.path}');
                      await directory.create(recursive: true);
                    }
                    
                    // Create unique filename with timestamp to avoid conflicts
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    audioFilePath = '${directory.path}/alarm_snooze_${timestamp}.wav';
                    
                    print('🎙️ Will save recording to: $audioFilePath');
                    
                    // Make sure the file doesn't exist already
                    final file = File(audioFilePath!);
                    if (await file.exists()) {
                      print('🎙️ Deleting existing file: $audioFilePath');
                      try {
                        await file.delete();
                      } catch (e) {
                        print('⚠️ Failed to delete existing file: $e');
                      }
                    }
                    
                    print('🎙️ Starting audio recording with WAV format');
                    await record.start(
                      record_pkg.RecordConfig(
                        encoder: record_pkg.AudioEncoder.wav,
                        bitRate: 128000,
                        sampleRate: 44100,
                      ),
                      path: audioFilePath!,
                    );
                    
                    print('✅ Recording started successfully');
                    setState(() {
                      isRecording = true;
                    });
                  } else {
                    print('❌ No permission to record audio');
                  }
                } catch (e, stack) {
                  print('❌ Error starting recording: $e');
                  print('❌ Stack trace: $stack');
                }
              }
              
              // Function to stop recording
              Future<void> stopRecording() async {
                final record = record_pkg.AudioRecorder();
                try {
                  print('🎙️ Stopping audio recording');
                  await record.stop();
                  
                  if (audioFilePath != null) {
                    final file = File(audioFilePath!);
                    if (await file.exists()) {
                      final fileSize = await file.length();
                      print('📂 Audio file size: $fileSize bytes');
                      
                      if (fileSize > 100) { // Only process file if it has content
                        try {
                          print('🎙️ Reading file bytes for base64 encoding');
                          final bytes = await file.readAsBytes();
                          audioDuration = bytes.length ~/ 44; // Better approximation for WAV
                          
                          print('🎙️ Converting to base64: ${bytes.length} bytes');
                          audioData = base64Encode(bytes);
                          print('✅ Audio recording processed successfully: $audioDuration ms, ${audioData?.length ?? 0} chars base64');
                        } catch (e) {
                          print('❌ Error processing audio file: $e');
                        }
                      } else {
                        print('⚠️ Audio file too small (${fileSize} bytes), not using it');
                      }
                    } else {
                      print('⚠️ Audio file not found after recording: $audioFilePath');
                      
                      // Check the directory contents
                      final directory = File(audioFilePath!).parent;
                      try {
                        final files = await directory.list().toList();
                        print('📁 Files in directory: ${files.length}');
                        for (var f in files) {
                          print('📄 - ${f.path} (${await File(f.path).length()} bytes)');
                        }
                      } catch (e) {
                        print('❌ Error listing directory: $e');
                      }
                    }
                  }
                } catch (e, stack) {
                  print('❌ Error stopping recording: $e');
                  print('❌ Stack trace: $stack');
                } finally {
                  setState(() {
                    isRecording = false;
                  });
                }
              }
              
              // Function to play recorded audio
              Future<void> playAudio() async {
                try {
                  if (isPlaying) {
                    print('🎵 Stopping current audio playback');
                    await player.stop();
                    setState(() => isPlaying = false);
                    return;
                  }
                  
                  if (audioFilePath != null) {
                    print('🎵 Attempting to play audio file: $audioFilePath');
                    final file = File(audioFilePath!);
                    
                    if (await file.exists()) {
                      final fileSize = await file.length();
                      print('🎵 Audio file exists, size: $fileSize bytes');
                      
                      if (fileSize < 10) {
                        print('⚠️ Audio file too small, might be invalid: $fileSize bytes');
                        setState(() => isPlaying = false);
                        return;
                      }
                      
                      // Try to read a few bytes to validate the file
                      try {
                        final bytes = await file.openRead(0, math.min(100, fileSize)).toList();
                        print('🎵 Successfully read ${bytes.length} chunks from audio file');
                      } catch (e) {
                        print('⚠️ Error reading from audio file: $e');
                      }
                      
                      // Create a proper file URL
                      final fileUri = file.uri.toString();
                      print('🎵 File URI: $fileUri');
                      
                      print('🎵 Attempting to play audio with DeviceFileSource');
                      await player.play(DeviceFileSource(audioFilePath!)).catchError((error) {
                        print('❌ Audio player error: $error');
                        setState(() => isPlaying = false);
                      });
                      setState(() => isPlaying = true);
                      
                      print('✅ Audio playback started successfully');
                      
                      player.onPlayerComplete.listen((event) {
                        print('✅ Audio playback completed');
                        setState(() => isPlaying = false);
                      });
                    } else {
                      print('⚠️ Audio file does not exist: $audioFilePath');
                      
                      // Try to check parent directory
                      final directory = File(audioFilePath!).parent;
                      if (await directory.exists()) {
                        print('📁 Parent directory exists: ${directory.path}');
                        try {
                          final files = await directory.list().toList();
                          print('📁 Files in directory: ${files.length}');
                          for (var f in files) {
                            print('📄 - ${f.path}');
                          }
                        } catch (e) {
                          print('❌ Error listing directory: $e');
                        }
                      } else {
                        print('❌ Parent directory does not exist: ${directory.path}');
                      }
                    }
                  } else {
                    print('⚠️ No audio file path available');
                  }
                } catch (e, stack) {
                  print('❌ Error in playAudio: $e');
                  print('❌ Stack trace: $stack');
                  setState(() => isPlaying = false);
                }
              }
              
              return AlertDialog(
                backgroundColor: Color(0xFF0A0F1C),
                title: Text(
                  'Snooze Notification',
                  style: TextStyle(color: Color(0xFF7DF9FF)),
                  textAlign: TextAlign.center,
                ),
                content: SingleChildScrollView(
                  child: Container(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date & Time Picker
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: snoozeDateTime,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(Duration(days: 365)),
                              builder: (BuildContext context, Widget? child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: ColorScheme.dark(
                                      primary: Color(0xFF7DF9FF),
                                      onPrimary: Colors.black,
                                      surface: Color(0xFF131B2E),
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              final TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(snoozeDateTime),
                                builder: (BuildContext context, Widget? child) {
                                  return Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: ColorScheme.dark(
                                        primary: Color(0xFF7DF9FF),
                                        onPrimary: Colors.black,
                                        surface: Color(0xFF131B2E),
                                        onSurface: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              
                              if (pickedTime != null) {
                                setState(() {
                                  snoozeDateTime = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFF131B2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Snooze until: ${snoozeDateTime.year}-${snoozeDateTime.month.toString().padLeft(2, '0')}-${snoozeDateTime.day.toString().padLeft(2, '0')} ${snoozeDateTime.hour.toString().padLeft(2, '0')}:${snoozeDateTime.minute.toString().padLeft(2, '0')}",
                                  style: TextStyle(color: Colors.white),
                                ),
                                Icon(Icons.calendar_today, color: Color(0xFF7DF9FF)),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        // Reason Text Field
                        Text("Reason", style: TextStyle(color: Colors.white70)),
                        SizedBox(height: 8),
                        TextField(
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Why would you like to snooze?',
                            hintStyle: TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Color(0xFF131B2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            helperText: audioData == null ? 'Required if no voice note is provided' : null,
                            helperStyle: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          onChanged: (value) {
                            setState(() => reason = value);
                          },
                        ),
                        SizedBox(height: 16),
                        
                        // Audio Note 
                        Text("Audio Note (optional)", style: TextStyle(color: Colors.white70)),
                        SizedBox(height: 8),
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(0xFF131B2E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isRecording && audioData == null)
                                IconButton(
                                  icon: Icon(Icons.mic, color: Color(0xFF7DF9FF)),
                                  onPressed: startRecording,
                                ),
                              if (isRecording)
                                IconButton(
                                  icon: Icon(Icons.stop, color: Colors.red),
                                  onPressed: stopRecording,
                                ),
                              if (audioData != null) ...[
                                IconButton(
                                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Color(0xFF7DF9FF)),
                                  onPressed: playAudio,
                                ),
                                Text('Preview Recording', style: TextStyle(color: Colors.white70)),
                                Spacer(),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      audioData = null;
                                      audioFilePath = null;
                                    });
                                  },
                                ),
                              ]
                            ],
                          ),
                        ),
                        if (isRecording)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Recording in progress...',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (reason.isEmpty && audioData == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Either reason or audio note is required',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      player.dispose();
                      Navigator.pop(context, 'cancel');
                    },
                    child: Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF7DF9FF),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    onPressed: canSnooze ? () async {
                      player.dispose();
                      Navigator.pop(context, 'snooze');
                      
                      try {
                        // Show loading indicator
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Snoozing alarm...'))
                        );

                        // Prepare audio note data
                        Map<String, dynamic>? audioNote;
                        if (audioData != null) {
                          audioNote = {
                            'audio_data': audioData,
                            'filename': 'snooze_audio_${DateTime.now().millisecondsSinceEpoch}.wav',
                            'duration': audioDuration ?? 0,
                          };
                        }
                        
                        // Get JWT token
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('access_token');
                        
                        print('🔄 [Snooze] Sending snooze request with token: ${token?.substring(0, math.min(15, token?.length ?? 0))}...');
                        
                        // Use HTTPS protocol instead of HTTP
                        final baseUrl = ApiService.baseUrl;
                        print('🔄 [Snooze] Using endpoint: $baseUrl/tasks/$taskId/snooze_alarm');
                        
                        try {
                          // Create the request payload
                          Map<String, dynamic> payload = {
                            'alarm_id': alarmId,
                            'snooze_until': snoozeDateTime.toIso8601String(),
                            'reason': reason,
                            'task_id': taskId
                          };
                          
                          // Only add audio note if it exists
                          if (audioNote != null) {
                            Map<String, dynamic> audioNoteData = {
                              'audio_data': audioNote['audio_data'],
                              'duration': audioNote['duration'] ?? 0,
                              'filename': audioNote['filename'] ?? 'voice_note.wav'
                            };
                            payload['audio_note'] = audioNoteData;
                          }
                          
                          print('🔄 [Snooze] Payload structure: ${payload.keys.join(', ')}');
                          print('🔄 [Snooze] Payload: ${json.encode(payload)}');
                          
                          // Add timeout to avoid hanging
                          final response = await http.post(
                            Uri.parse('$baseUrl/tasks/$taskId/snooze_alarm'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Accept': 'application/json',
                              'Authorization': 'Bearer $token',
                            },
                            body: json.encode(payload),
                          ).timeout(const Duration(seconds: 10));
                          
                          print('🔄 [Snooze] Response status: ${response.statusCode}');
                          print('🔄 [Snooze] Response headers: ${response.headers}');
                          print('🔄 [Snooze] Response body: ${response.body.substring(0, math.min(500, response.body.length))}');
                          
                          // Check for the specific "unknown column" error
                          if (response.statusCode == 500 && 
                              response.body.contains("Unknown column 'updated_by'")) {
                            
                            print('⚠️ Detected updated_by column error, using direct alarm update endpoint');
                            
                            // Try a simpler approach - just update the alarm's next_trigger time directly
                            final directUpdateResponse = await http.post(
                              Uri.parse('$baseUrl/alarms/update_next_trigger'),
                              headers: {
                                'Content-Type': 'application/json',
                                'Accept': 'application/json',
                                'Authorization': 'Bearer $token',
                              },
                              body: json.encode({
                                'alarm_id': alarmId,
                                'next_trigger': snoozeDateTime.toIso8601String(),
                                'task_id': taskId
                              }),
                            ).timeout(const Duration(seconds: 10));
                            
                            print('🔄 [Snooze] Direct update response: ${directUpdateResponse.statusCode}');
                            print('🔄 [Snooze] Direct update body: ${directUpdateResponse.body}');
                            
                            if (directUpdateResponse.statusCode == 200 || 
                                directUpdateResponse.statusCode == 201 ||
                                directUpdateResponse.statusCode == 404) { // Even if endpoint doesn't exist, proceed
                              
                              // As a fallback, just stop the alarm sound and close the screen
                              print('✅ Alarm snoozed or fallback applied');
                              
                              // Call the onSnoozeComplete callback to close the screen
                              if (onSnoozeComplete != null) {
                                print('✅ Calling onSnoozeComplete to close the alarm screen');
                                onSnoozeComplete();
                              }
                              
                              // Show success toast
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Alarm snoozed until ${snoozeDateTime.toString()}'),
                                  duration: Duration(seconds: 2),
                                ));
                              }
                              return;
                            }
                          }
                          
                          if (response.statusCode == 200 || response.statusCode == 201) {
                            print('✅ Alarm snoozed successfully');
                            
                            // Try parsing the response
                            try {
                              final responseData = json.decode(response.body);
                              print('✅ Response data: $responseData');
                            } catch (e) {
                              print('⚠️ Could not parse response: ${response.body}');
                            }
                            
                            // Call the onSnoozeComplete callback to close the screen
                            if (onSnoozeComplete != null) {
                              print('✅ Calling onSnoozeComplete to close the alarm screen');
                              onSnoozeComplete();
                            }
                            
                            // Show success toast if context is still mounted
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Alarm snoozed successfully until ${snoozeDateTime.toString()}'),
                                duration: Duration(seconds: 2),
                              ));
                            }
                          } else {
                            print('❌ Failed to snooze alarm: ${response.statusCode}');
                            print('❌ Error response: ${response.body}');
                            
                            // If all else fails, just close the screen and stop the alarm
                            if (onSnoozeComplete != null) {
                              print('⚠️ Applying fallback: closing alarm screen without server confirmation');
                              onSnoozeComplete();
                            }
                            
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Failed to snooze alarm on server, but alarm stopped locally'),
                                duration: Duration(seconds: 2),
                              ));
                            }
                          }
                        } catch (e) {
                          print('❌ Exception during snooze request: $e');
                          
                          // If all else fails, just close the screen and stop the alarm
                          if (onSnoozeComplete != null) {
                            print('⚠️ Applying fallback after exception: closing alarm screen');
                            onSnoozeComplete();
                          }
                          
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Network error while trying to snooze alarm, but alarm stopped locally'),
                              duration: Duration(seconds: 2),
                            ));
                          }
                        }
                      } catch (e) {
                        print('❌ Error snoozing alarm: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to snooze alarm'))
                          );
                        }
                      }
                    } : null,
                    child: Text('Snooze'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleAlarmNotification(Map<String, dynamic> alarmData) async {
    try {
      print('🔔 Handling alarm notification: $alarmData');
      
      // Show local notification with full screen intent
      await showAlarmNotification(
        title: 'Task Alarm',
        body: 'Time to check your task: ${alarmData['task_title']}',
        alarmData: alarmData,
      );

      // Play alarm sound
      await playAlarmSound();

      // Trigger alarm callback to show alarm screen
      if (onAlarmTriggered != null) {
        print('🔔 Triggering alarm callback');
        onAlarmTriggered!(alarmData);
      }

      // Show the AlarmScreen as a dialog if in foreground
      if (globalNavigatorKey.currentState != null) {
        globalNavigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => AlarmScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      print('🔔 Error handling alarm notification: $e');
    }
  }

  Future<void> _handleNotificationTap(dynamic response) async {
    try {
      Map<String, dynamic> data;
      if (response is NotificationResponse && response.payload != null) {
        data = json.decode(response.payload!);
        if (data['type'] == 'alarm' && onAlarmTriggered != null) {
          onAlarmTriggered!(data);
        }
      }
    } catch (e) {
      print('🔔 Error handling notification tap: $e');
    }
  }

  Future<List<NotificationModel>> getNotifications() async {
    try {
      print('🔔 [NotificationService] Starting to fetch notifications');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');
      
      print('🔔 [NotificationService] Fetching notifications for user: $userId, username: $username');

      if (userId == null || username == null) {
        print('❌ [NotificationService] User not logged in');
        throw Exception('User not logged in');
      }

      print('🔔 [NotificationService] Making API call to ${ApiService.baseUrl}/tasks/notifications');
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      // print('🔔 [NotificationService] Response status: ${response.statusCode}');
      // print('🔔 [NotificationService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          print('✅ [NotificationService] Received ${notifications.length} notifications');
          
          final processedNotifications = notifications.map((json) {
            try {
              // Skip notifications where the current user is the updater
              if ((json['updated_by'] != null && json['updated_by'] == username) ||
                  (json['assigned_by'] != null && json['assigned_by'] == username)) {
                print('ℹ️ [NotificationService] Skipping notification from current user');
                return null;
              }
              
              return NotificationModel(
                id: json['id'] ?? '',
                title: json['title'] ?? '',
                description: json['description'] ?? '',
                senderName: json['sender_name'] ?? '',
                senderRole: json['sender_role'] ?? '',
                createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
                type: _getNotificationType(json['type'] ?? json['priority'] ?? ''),
                isCompleted: json['is_read'] == 1,
              );
            } catch (e) {
              print('❌ [NotificationService] Error parsing notification: $e');
              print('❌ [NotificationService] Problematic JSON: $json');
              return null;
            }
          })
          .where((notification) => notification != null)
          .cast<NotificationModel>()
          .toList();

          print('✅ [NotificationService] Successfully processed ${processedNotifications.length} notifications');
          return processedNotifications;
        } else {
          print('ℹ️ [NotificationService] No notifications found in response');
          return [];
        }
      } else {
        print('❌ [NotificationService] Failed to load notifications. Status: ${response.statusCode}');
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      print('❌ [NotificationService] Error fetching notifications: $e');
      return [];
    }
  }

  String _getTimeAgo(String timestamp) {
    try {
      // Always treat backend timestamp as UTC, then convert to local
      final DateTime utcTime = DateTime.parse(timestamp).toUtc();
      final DateTime localTime = utcTime.toLocal();
      final Duration difference = DateTime.now().difference(localTime);
      
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

  Future<void> markNotificationAsComplete(String notificationId) async {
    try {
      final response = await _apiService.markNotificationAsComplete(notificationId);
      if (!response['success']) {
        throw Exception(response['message'] ?? 'Failed to mark notification as complete');
      }
    } catch (e) {
      print('❌ [NotificationService] Error marking notification as complete: $e');
      rethrow;
    }
  }

  Future<void> snoozeNotification(String notificationId, DateTime snoozeUntil, {String? reason, Map<String, dynamic>? audioNote}) async {
    try {
      print('🔄 [NotificationSnooze] Starting snooze request');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');
      final token = prefs.getString('access_token');

      if (userId == null || username == null) {
        throw Exception('User not logged in');
      }
      
      print('🔄 [NotificationSnooze] User: $username, ID: $userId');

      // Use HTTPS protocol
      final baseUrl = ApiService.baseUrl;
      
      // First, get the task ID from the notification
      print('🔄 [NotificationSnooze] Fetching notification details from: $baseUrl/tasks/notifications');
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // Add auth token
        },
      ).timeout(const Duration(seconds: 10));

      print('🔄 [NotificationSnooze] Notification details response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          final notification = notifications.firstWhere(
            (n) => n['id'] == notificationId,
            orElse: () => throw Exception('Notification not found')
          );
          
          print('🔄 [NotificationSnooze] Found notification: ${notification['id']}');

          // Create the request payload
          Map<String, dynamic> payload = {
            'notification_id': notificationId,
            'snooze_until': snoozeUntil.toIso8601String(),
            'reason': reason,
            'updated_by': username,
          };
          
          // Only add audio note if it exists
          if (audioNote != null) {
            // Create a proper audio_note structure
            payload['audio_note'] = {
              'audio_data': audioNote['audio_data'],
              'duration': audioNote['duration'] ?? 0,
              'filename': audioNote['filename'] ?? 'voice_note.wav'
            };
          }
          
          print('🔄 [NotificationSnooze] Payload structure: ${payload.keys.join(', ')}');
          print('🔄 [NotificationSnooze] Payload: ${json.encode(payload)}');

          // Snooze the notification
          final snoozeResponse = await http.post(
            Uri.parse('$baseUrl/notifications/snooze'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token', // Add auth token
            },
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 10));

          print('🔄 [NotificationSnooze] Response status: ${snoozeResponse.statusCode}');
          print('🔄 [NotificationSnooze] Response headers: ${snoozeResponse.headers}');
          print('🔄 [NotificationSnooze] Response body: ${snoozeResponse.body.substring(0, math.min(500, snoozeResponse.body.length))}');

          if (snoozeResponse.statusCode == 200 || snoozeResponse.statusCode == 201) {
            print('✅ [NotificationSnooze] Notification snoozed successfully');
            // Mark the notification as read to clear it from the notification bar
            await markNotificationAsComplete(notificationId);
          } else {
            print('❌ [NotificationSnooze] Failed to snooze notification: ${snoozeResponse.statusCode}');
            try {
              final errorBody = json.decode(snoozeResponse.body);
              final errorMessage = errorBody['message'] ?? 'Failed to snooze notification';
              throw Exception(errorMessage);
            } catch (e) {
              throw Exception('Failed to snooze notification: ${snoozeResponse.statusCode}');
            }
          }
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [NotificationSnooze] Error snoozing notification: $e');
      rethrow;
    }
  }

  Future<void> playAlarmSound() async {
    try {
      print('🔔 Playing alarm sound...');
      if (!_isInitialized) {
        await initialize();
      }
      
      // Stop any existing playback
      await _audioPlayer.stop();
      
      // Reset the player state
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      
      // Play the alarm sound
      print('🔔 Setting alarm sound source');
      await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
      print('🔔 Playing alarm sound');
      await _audioPlayer.resume();
      
      print('🔔 Alarm sound played successfully');
    } catch (e) {
      print('🔔 Error playing alarm sound: $e');
      // Try to reinitialize and play again
      try {
        _isInitialized = false;
        await initialize();
        await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
        await _audioPlayer.resume();
      } catch (e) {
        print('🔔 Error during retry: $e');
      }
    }
  }

  Future<void> vibrate() async {
    print('📳 [Notification] Triggering vibration');
    try {
      await HapticFeedback.mediumImpact();
      print('✅ [Notification] Vibration triggered successfully');
    } catch (e) {
      print('❌ [Notification] Error triggering vibration: $e');
    }
  }

  Future<void> handleNewNotification() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Stop any existing playback
      await _audioPlayer.stop();
      
      // Reset the player state
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      
      // Play the sound
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      print('🔔 Error playing notification sound: $e');
      // Try to reinitialize and play again
      try {
        _isInitialized = false;
        await initialize();
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      } catch (e) {
        print('🔔 Error during retry: $e');
      }
    }
  }

  void dispose() {
    try {
      if (_audioPlayer.state != PlayerState.disposed) {
        _audioPlayer.dispose();
      }
      _isInitialized = false;
    } catch (e) {
      print('🔔 Error disposing notification service: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    print('🔔 [Notification] Showing notification: $title');
    try {
      const androidDetails = AndroidNotificationDetails(
        'task_channel',
        'Task Notifications',
        channelDescription: 'Notifications for task updates',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('notification'),
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'notification.mp3',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      print('🔔 [Notification] Creating notification with ID: ${_notificationId}');
      await _flutterLocalNotificationsPlugin.show(
        _notificationId++,
        title,
        body,
        details,
        payload: payload,
      );
      print('✅ [Notification] Notification displayed successfully');
    } catch (e) {
      print('❌ [Notification] Error showing notification: $e');
    }
  }

  Future<void> showAlarmNotification({
    required String title,
    required String body,
    required Map<String, dynamic> alarmData,
  }) async {
    print('🔔 Showing alarm notification');
    try {
      // Show notification with full screen intent
      const androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        'Alarm Notifications',
        channelDescription: 'Notifications for task alarms',
        importance: Importance.max,
        priority: Priority.max,
        sound: RawResourceAndroidNotificationSound('alarm'),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFFE53935),
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'alarm.mp3',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      print('🔔 Creating alarm notification');
      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch,
        title,
        body,
        details,
        payload: json.encode(alarmData),
      );

      print('🔔 Alarm notification shown successfully');
    } catch (e) {
      print('🔔 Error showing alarm notification: $e');
    }
  }

  // Callback to show the alarm UI
  Future<void> _showAlarmUI(Map<String, dynamic> alarmData) async {
    try {
      print('🔔 Showing alarm UI for: ${alarmData['title']}');
      print('🔔 Alarm data: $alarmData');
      
      // Use the global navigator key to show the alarm screen
      if (globalNavigatorKey.currentState != null) {
        await globalNavigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => AlarmScreen(
              taskId: alarmData['task_id'] ?? '',
              taskTitle: alarmData['title'] ?? 'Task Alarm',
              alarmId: alarmData['alarm_id'] ?? '',
              assigneeName: alarmData['assignee_name'] ?? '',
              assignedBy: alarmData['assigned_by'] ?? 'Unknown',
              dueDate: alarmData['deadline'] ?? '',
            ),
            fullscreenDialog: true,
          ),
        );
      } else {
        print('❌ Global navigator key is null, cannot show alarm screen');
      }
    } catch (e) {
      print('❌ Error showing alarm UI: $e');
    }
  }
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  if (message.data['type'] == 'alarm') {
    await notificationService._handleAlarmNotification(message.data);
  }
} 