import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskmanagement/services/notification_firebase_service.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';
import '../models/task_assignment.dart';
import '../models/voice_note.dart';
import 'send_notification_service.dart';

class ApiService {
  static const String baseUrl = 'http://134.209.149.12:5001';
  // static const String baseUrl = 'http://10.20.0.248:5000';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    validateStatus: (status) => true,
  ));

  ApiService() {
    setupFcmTokenRefreshListener();
  }

  void setupFcmTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM Token Refreshed: $newToken');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);

      final username = prefs.getString('username');
      if (username != null) {
        await updateFcmTokenInBackend(username, newToken);
      } else {
        print('User not logged in, cannot update FCM token in backend');
      }
    }).onError((e) {
      print('Error listening for FCM token refresh: $e');
    });
  }

  Future<String?> getAndStoreFcmToken() async {
    try {
      String? fcmToken = await NotificationFirebaseService().getDeviceToken();
      print('Retrieved FCM Token: $fcmToken');

      if (fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
      } else {
        print('FCM token retrieval returned null');
      }

      return fcmToken;
    } catch (e) {
      print('Error retrieving FCM token: $e');
      return null;
    }
  }

  Future<void> updateFcmTokenInBackend(String username, String fcmToken) async {
    final result = await updateFcmToken(username, fcmToken);
    if (result['success']) {
      print('FCM token updated in backend: $fcmToken');
    } else {
      print('Failed to update FCM token in backend: ${result['message']}');
    }
  }

  Future<Map<String, dynamic>> updateFcmToken(String username, String fcmToken) async {
    try {
      print('Updating FCM token for username: $username');
      print('FCM token to update: $fcmToken');

      // First get the user_id for the username using POST request
      final response = await http.post(
        Uri.parse('$baseUrl/get_fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'username': username,
        }),
      );

      print('Get FCM token response status: ${response.statusCode}');
      print('Get FCM token response body: ${response.body}');

      if (response.statusCode != 200) {
        print('Failed to get user ID. Status: ${response.statusCode}, Body: ${response.body}');
        return {
          'success': false,
          'message': 'Failed to get user ID',
        };
      }

      final userData = json.decode(response.body);
      final userId = userData['user_id'];

      if (userId == null) {
        print('User ID not found in response: ${response.body}');
        return {
          'success': false,
          'message': 'User ID not found',
        };
      }

      print('Retrieved user ID: $userId');

      // Now update the FCM token
      final updateResponse = await http.post(
        Uri.parse('$baseUrl/update_fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'user_id': userId,
          'fcm_token': fcmToken,
        }),
      );

      print('Update FCM token response status: ${updateResponse.statusCode}');
      print('Update FCM token response body: ${updateResponse.body}');

      final data = json.decode(updateResponse.body);
      if (updateResponse.statusCode == 200) {
        print('FCM token updated successfully in database');
        return {
          'success': true,
          'message': data['message'] ?? 'FCM token updated successfully',
        };
      } else {
        print('Failed to update FCM token in database');
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update FCM token',
        };
      }
    } catch (e) {
      print('Error updating FCM token: $e');
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  Future<String?> getUserFcmToken(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'username': username}),
      );

      print('Fetch FCM token response status: ${response.statusCode}');
      print('Fetch FCM token response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['fcm_token'];
      } else {
        print('Failed to fetch FCM token for user $username');
        return null;
      }
    } catch (e) {
      print('Error fetching FCM token for user $username: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      print('Sending signup request with data:');
      
      // Get FCM token before registration
      String? fcmToken = await getAndStoreFcmToken();
      
      final requestBody = {
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
        'fcm_token': fcmToken ?? '', // Include FCM token in registration
      };
      print(requestBody);

      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Store user data in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('role', role);
        if (fcmToken != null) {
          await prefs.setString('fcm_token', fcmToken);
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'message': 'User already exists',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': data['message'] ?? 'Missing required fields',
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      print('Registration error: $e');
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print('Attempting login for user: $username');

      // Get stored FCM token
      final prefs = await SharedPreferences.getInstance();
      final storedFcmToken = prefs.getString('fcm_token');
      print('Stored FCM token: $storedFcmToken');

      // Always get fresh FCM token from device
      final freshFcmToken = await NotificationFirebaseService().getDeviceToken();
      print('Fresh FCM token from device: $freshFcmToken');

      // If we got a fresh token and it's different from stored token, update it
      if (freshFcmToken != null && freshFcmToken.isNotEmpty) {
        if (storedFcmToken != freshFcmToken) {
          print('FCM token has changed, updating...');
          await prefs.setString('fcm_token', freshFcmToken);
        }
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'username': username,
              'password': password,
              'fcm_token': freshFcmToken ?? '', // Use fresh token in login request
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Store user data in SharedPreferences
        await prefs.setString('user_id', data['user_id'].toString());
        await prefs.setString('username', data['username']);
        await prefs.setString('role', data['role']);

        // Always update FCM token in backend after successful login
        if (freshFcmToken != null && freshFcmToken.isNotEmpty) {
          print('Updating FCM token in backend after successful login');
          final updateResult = await updateFcmToken(username, freshFcmToken);
          print('FCM token update result: $updateResult');
        } else {
          print('No FCM token available to update after login');
        }

        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } on TimeoutException {
      print('Login request timed out');
      return {
        'success': false,
        'message':
            'Connection timed out. Please check your internet connection.',
      };
    } on SocketException {
      print('Network error during login');
      return {
        'success': false,
        'message': 'Network error. Please check your internet connection.',
      };
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> getTasks({
    required String username,
    required String role,
  }) async {
    try {
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(seconds: 1);

      while (retryCount < maxRetries) {
        try {
          print('🔍 [API] Fetching tasks for user: $username with role: $role');
          final response = await http.get(
            Uri.parse('$baseUrl/tasks?username=$username&role=$role'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 10));

          print('📥 [API] Tasks response status: ${response.statusCode}');
          print('📥 [API] Tasks response body: ${response.body}');

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            return {
              'success': true,
              'data': data,
            };
          }
          return {
            'success': false,
            'message': 'Failed to load tasks',
          };
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            print('Retry attempt $retryCount after error: $e');
            await Future.delayed(retryDelay);
            continue;
          }
          rethrow;
        }
      }

      return {
        'success': false,
        'message': 'Failed after $maxRetries retry attempts',
      };
    } catch (e) {
      print('Error loading tasks: $e');
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  Future<List<String>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((user) => user.toString()).toList();
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print('Error fetching users: $e');
      throw Exception('Failed to load users');
    }
  }

  Future<String> createTask({
    required String title,
    required String description,
    required String assignedTo,
    required String assignedBy,
    required DateTime deadline,
    required String priority,
    required String status,
    Map<String, dynamic>? audioNote,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? alarmSettings,
  }) async {
    try {
      final taskData = {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'assigned_by': assignedBy,
        'deadline': deadline.toIso8601String(),
        'priority': priority,
        'status': status,
        'audio_note': audioNote,
        'alarm_settings': alarmSettings,
        'attachments': attachments,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(taskData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return responseData['task_id'];
      } else {
        throw Exception(
            'Failed to create task: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException {
      throw Exception(
          'Connection timed out. Please check your internet connection and try again.');
    } on SocketException catch (e) {
      throw Exception(
          'Network error: ${e.message}. Please check your internet connection.');
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<List<VoiceNote>> getTaskVoiceNotes(String taskId) async {
    try {
      print('📞 [API] Fetching voice notes for task: $taskId');
      final response = await _dio.get('/tasks/$taskId/audio');

      print('✅ [API] Voice notes response status: ${response.statusCode}');
      print('✅ [API] Voice notes response data: ${response.data}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          return VoiceNote.fromJson(json, parentTaskId: taskId);
        }).toList();
      } else if (response.statusCode == 404) {
        print('ℹ️ [API] No voice notes found for task');
        return [];
      } else {
        throw Exception(
            'Failed to fetch voice notes: ${response.statusMessage}');
      }
    } catch (e) {
      print('❌ [API] Error getting task voice notes: $e');
      return [];
    }
  }

  Future<String?> downloadVoiceNote(VoiceNote voiceNote) async {
    try {
      // If we already have audio data, save it to a file
      if (voiceNote.audioData != null) {
        print('📝 [API] Saving voice note from audio data');
        final tempDir = await getTemporaryDirectory();
        final fileName = voiceNote.fileName.isNotEmpty ? voiceNote.fileName : 'voice_note.wav';
        final file = File('${tempDir.path}/$fileName');
        final bytes = base64.decode(voiceNote.audioData!);
        await file.writeAsBytes(bytes);
        print('✅ [API] Voice note saved successfully');
        return file.path;
      }

      // Always use the API endpoint for download, not the filePath
      if (voiceNote.taskId != null && voiceNote.id != null) {
        final url = '/api/tasks/${voiceNote.taskId}/audio/${voiceNote.id}/download';
        print('📥 [API] Downloading voice note from endpoint: $url');
        final response = await _dio.get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status! < 500,
          ),
        );

        print('📥 [API] Download response status: ${response.statusCode}');
        print('📥 [API] Download response headers: ${response.headers}');

        if (response.statusCode == 200) {
          final bytes = response.data as List<int>;
          final tempDir = await getTemporaryDirectory();
          final fileName = voiceNote.fileName.isNotEmpty ? voiceNote.fileName : 'voice_note.wav';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          print('✅ [API] Voice note downloaded and saved successfully');
          return file.path;
        } else {
          print('❌ [API] Failed to download voice note: ${response.statusCode}');
          print('❌ [API] Error response: ${response.data}');
          return null;
        }
      }

      print('❌ [API] No audio data or valid IDs available for download');
      return null;
    } catch (e) {
      print('❌ [API] Error downloading voice note: $e');
      return null;
    }
  }

  Future<List<Attachment>> getTaskAttachments(String taskId) async {
    try {
      final response = await _dio.get('/tasks/$taskId/attachments');
      if (response.statusCode == 200) {
        final List<dynamic> attachments = response.data['attachments'];
        return attachments
            .map((attachment) => Attachment.fromJson(attachment))
            .toList();
      } else {
        throw Exception('Failed to fetch attachments');
      }
    } catch (e) {
      print('❌ [API] Error getting task attachments: $e');
      throw Exception('Failed to fetch attachments: $e');
    }
  }

  Future<String> downloadAttachment(String attachmentId) async {
    try {
      final response = await _dio.get(
        '/attachments/$attachmentId',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final bytes = response.data as List<int>;
        final tempDir = await getTemporaryDirectory();
        final fileName = response.headers
                .value('content-disposition')
                ?.split('filename=')
                .last ??
            'attachment_$attachmentId';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return file.path;
      } else {
        throw Exception('Failed to download attachment');
      }
    } catch (e) {
      print('❌ [API] Error downloading attachment: $e');
      throw Exception('Failed to download attachment: $e');
    }
  }

  Future<Map<String, dynamic>> getAudioNote(String taskId) async {
    try {
      print('📞 [API] Fetching audio note for task: $taskId');
      final response = await _dio.get('/tasks/$taskId/audio');
      print('✅ [API] Audio note response status: ${response.statusCode}');
      print('✅ [API] Audio note response data: ${response.data}');

      if (response.statusCode == 404) {
        print('ℹ️ [API] No audio note found for task');
        return {'success': true, 'data': null};
      }

      if (response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to get audio note: ${response.statusMessage}',
        );
      }

      return {
        'success': true,
        'data': response.data,
      };
    } catch (e) {
      print('❌ [API] Error getting audio note: $e');
      return {
        'success': false,
        'message': 'Failed to download audio note',
      };
    }
  }

  Future<Map<String, dynamic>> getAttachment(String attachmentId) async {
    try {
      print('📞 [API] Fetching attachment: $attachmentId');
      final response = await _dio.get('/attachments/$attachmentId');
      print('✅ [API] Attachment response status: ${response.statusCode}');
      print('✅ [API] Attachment response data: ${response.data}');

      if (response.statusCode == 404) {
        print('ℹ️ [API] Attachment not found');
        return {'success': false, 'message': 'Attachment not found'};
      }

      if (response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to get attachment: ${response.statusMessage}',
        );
      }

      return {
        'success': true,
        'data': response.data,
      };
    } catch (e) {
      print('❌ [API] Error downloading attachment: $e');
      return {
        'success': false,
        'message': 'Failed to download attachment',
      };
    }
  }

  Future<List<TaskAssignment>> getTaskAssignments(String userId) async {
    try {
      print('🔍 [API] Fetching task assignments for user: $userId');
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/assignments/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print(
          '📥 [API] Task assignments response status: ${response.statusCode}');
      print('📥 [API] Task assignments response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['assignments'];
        return data.map((json) => TaskAssignment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch task assignments');
      }
    } catch (e) {
      print('❌ [API] Error fetching task assignments: $e');
      throw Exception('Error fetching task assignments: $e');
    }
  }

  Future<String> updateTask({
    required String taskId,
    required String title,
    required String description,
    required String assignedTo,
    required String assignedBy,
    required DateTime deadline,
    required String priority,
    required String status,
    Map<String, dynamic>? audioNote,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? alarmSettings,
  }) async {
    try {
      // Get current user from SharedPreferences to determine who is updating
      final prefs = await SharedPreferences.getInstance();
      final updatedBy = prefs.getString('username') ??
          assignedBy; // Fallback to assignedBy if not found

      final taskData = {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'assigned_by': assignedBy,
        'deadline': deadline.toIso8601String(),
        'priority': priority,
        'status': status,
        'updated_by': updatedBy,
        'audio_note': audioNote,
        'alarm_settings': alarmSettings,
        'attachments': attachments,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(taskData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['task_id'];
      } else {
        throw Exception(
            'Failed to update task: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  Future<Map<String, dynamic>> getCompletedTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks?status=completed'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to load completed tasks',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');
      
      print('🔔 [API] Fetching notifications for user: $userId, username: $username');

      if (userId == null || username == null) {
        print('❌ [API] User not logged in - missing userId or username');
        throw Exception('User not logged in');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/tasks/notifications?user_id=$userId&username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('🔔 [API] Notifications response status: ${response.statusCode}');
      print('🔔 [API] Notifications response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Check if response has notifications array
        if (responseData['notifications'] != null) {
          final List<dynamic> notifications = responseData['notifications'];
          print('✅ [API] Received ${notifications.length} notifications from server');
          
          final processedNotifications = notifications.map((json) {
            // Skip notifications where the current user is the updater
            if ((json['updated_by'] != null && json['updated_by'] == username) ||
                (json['assigned_by'] != null && json['assigned_by'] == username)) {
              return null;
            }
            
            return {
              'id': json['id']?.toString() ?? '',
              'title': json['title']?.toString() ?? '',
              'message': json['description']?.toString() ?? '',
              'timestamp': json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              'type': json['type']?.toString() ?? json['priority']?.toString() ?? '',
              'isRead': json['is_read'] == 1,
              'taskId': json['task_id']?.toString(),
              'updatedBy': json['updated_by']?.toString(),
              'assignedBy': json['assigned_by']?.toString(),
            };
          })
          .where((notification) => notification != null)
          .cast<Map<String, dynamic>>()
          .toList();

          print('✅ [API] Processed ${processedNotifications.length} valid notifications');
          return processedNotifications;
        } else {
          print('ℹ️ [API] No notifications found in response');
          return [];
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ [API] No notifications found (404)');
        return [];
      } else {
        print('❌ [API] Failed to load notifications. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } on TimeoutException {
      print('❌ [API] Timeout while fetching notifications');
      throw Exception('Connection timed out. Please try again.');
    } catch (e) {
      print('❌ [API] Error fetching notifications: $e');
      throw Exception('Failed to load notifications: $e');
    }
  }

  Future<Map<String, dynamic>> markNotificationAsComplete(String notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark_read/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Mark complete response status: ${response.statusCode}');
      print('Mark complete response body: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Notification marked as complete',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to mark notification as complete',
        };
      }
    } catch (e) {
      print('❌ [ApiService] Error marking notification as complete: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> registerTaskAlarm({
    required String taskId,
    required String assignedTo,
    required DateTime startDate,
    required String startTime,
    required String frequency,
  }) async {
    try {
      print('⏰ [API] Registering task alarm with backend...');
      print('⏰ [API] Task ID: $taskId');
      print('⏰ [API] Assigned To: $assignedTo');
      print('⏰ [API] Start Date: ${startDate.toIso8601String()}');
      print('⏰ [API] Start Time: $startTime');
      print('⏰ [API] Frequency: $frequency');
      
      final data = {
        'task_id': taskId,
        'assigned_to': assignedTo,
        'start_date': startDate.toIso8601String().split('T')[0],
        'start_time': startTime,
        'frequency': frequency,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/alarms/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );
      
      print('⏰ [API] Register alarm response status: ${response.statusCode}');
      print('⏰ [API] Register alarm response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('✅ [API] Alarm registered successfully');
        return {
          'success': true,
          'message': responseData['message'] ?? 'Alarm registered successfully',
          'alarm_id': responseData['alarm_id'],
        };
      } else {
        print('❌ [API] Failed to register alarm');
        return {
          'success': false,
          'message': 'Failed to register alarm',
          'error': response.body,
        };
      }
    } catch (e) {
      print('❌ [API] Error registering task alarm: $e');
      return {
        'success': false,
        'message': 'Error registering task alarm',
        'error': e.toString(),
      };
    }
  }
}
