import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/attachment.dart';
import '../models/task_assignment.dart';
import '../models/voice_note.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ApiService {
  static const String baseUrl = 'http://134.209.149.12:5000';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    validateStatus: (status) => true,
  ));

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      print('Sending signup request with data:');
      final requestBody = {
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
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
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        // Store user data in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', data['user_id']);
        await prefs.setString('username', data['username']);
        await prefs.setString('role', data['role']);
        
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
    } catch (e) {
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
      final response = await http.get(
        Uri.parse('$baseUrl/tasks?username=$username&role=$role'),
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
          'message': 'Failed to load tasks',
        };
      }
    } catch (e) {
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

  Future<Map<String, dynamic>> createTask({
    required String title,
    required String description,
    required String assignedTo,
    required String assignedBy,
    required String deadline,
    required String priority,
    required String status,
    String? audioNote,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? alarmSettings,
  }) async {
    try {
      print('Creating task with data:');
      final requestBody = {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'assigned_by': assignedBy,
        'deadline': deadline,
        'priority': priority,
        'status': status,
        if (audioNote != null) 'audio_note': {
          'audio_data': audioNote,
          'duration': 0, // Add duration if available
        },
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments,
        if (alarmSettings != null) 'alarm_settings': alarmSettings,
      };
      print(requestBody);

      final response = await http.post(
        Uri.parse('$baseUrl/create_task'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      final responseData = json.decode(response.body);
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Task created successfully',
          'statusCode': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to create task',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('Error creating task: $e');
      return {
        'success': false,
        'message': 'Error creating task: $e',
        'statusCode': 500,
      };
    }
  }

  Future<List<VoiceNote>> getTaskVoiceNotes(String taskId) async {
    try {
      final response = await _dio.get('/tasks/$taskId/voice_notes');
      if (response.statusCode == 200) {
        final List<dynamic> voiceNotes = response.data['voice_notes'];
        return voiceNotes.map((note) => VoiceNote.fromJson(note)).toList();
      } else {
        throw Exception('Failed to fetch voice notes');
      }
    } catch (e) {
      print('❌ [API] Error getting task voice notes: $e');
      throw Exception('Failed to fetch voice notes: $e');
    }
  }

  Future<String> downloadVoiceNote(String taskId, String audioId) async {
    try {
      print('📥 [API] Downloading voice note - Task: $taskId, Audio: $audioId');
      final response = await _dio.get(
        '/tasks/$taskId/audio',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': '*/*',
          },
          validateStatus: (status) => true,
        ),
      );

      print('📥 [API] Download response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final bytes = response.data as List<int>;
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/voice_note_$audioId.wav');
        
        // Check if file exists and delete it
        if (await file.exists()) {
          print('📥 [API] Deleting existing file: ${file.path}');
          await file.delete();
        }

        // Write new file
        await file.writeAsBytes(bytes, flush: true);
        
        // Verify file was written correctly
        if (await file.exists()) {
          final size = await file.length();
          print('📥 [API] File saved successfully:');
          print('  - Path: ${file.path}');
          print('  - Size: $size bytes');
          
          if (size == 0) {
            throw Exception('Downloaded file is empty');
          }
          
          return file.path;
        } else {
          throw Exception('File was not created');
        }
      } else {
        print('❌ [API] Error response: ${response.statusCode}');
        print('❌ [API] Error data: ${response.data}');
        throw Exception('Failed to download voice note: ${response.statusMessage}');
      }
    } catch (e) {
      print('❌ [API] Error downloading voice note: $e');
      throw Exception('Failed to download voice note: $e');
    }
  }

  Future<List<Attachment>> getTaskAttachments(String taskId) async {
    try {
      final response = await _dio.get('/tasks/$taskId/attachments');
      if (response.statusCode == 200) {
        final List<dynamic> attachments = response.data['attachments'];
        return attachments.map((attachment) => Attachment.fromJson(attachment)).toList();
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
        final fileName = response.headers.value('content-disposition')?.split('filename=').last ?? 'attachment_$attachmentId';
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
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/assignments/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['assignments'];
        return data.map((json) => TaskAssignment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch task assignments');
      }
    } catch (e) {
      throw Exception('Error fetching task assignments: $e');
    }
  }

  Future<Map<String, dynamic>> updateTask({
    required String taskId,
    required String priority,
    required String status,
    required String deadline,
    String? audioNote,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? alarmSettings,
    required String updatedBy,
  }) async {
    try {
      print('Updating task with data:');
      final requestBody = {
        'task_id': taskId,
        'priority': priority,
        'status': status,
        'deadline': deadline,
        'updated_by': updatedBy,
        if (audioNote != null) 'audio_note': {
          'audio_data': audioNote,
          'file_name': 'audio_note_${DateTime.now().millisecondsSinceEpoch}.m4a',
          'duration': 0
        },
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments.map((attachment) => {
            'file_name': attachment['file_name'],
            'file_type': attachment['file_type'],
            'file_size': attachment['file_size'],
            'file_data': attachment['file_data'],
          }).toList(),
        if (alarmSettings != null) 'alarm_settings': alarmSettings,
      };
      print('Request body (excluding file data): ${json.encode({
        ...requestBody,
        if (audioNote != null) 'audio_note': {'file_name': 'audio_note_${DateTime.now().millisecondsSinceEpoch}.m4a'},
        if (attachments != null) 'attachments': attachments!.map((a) => a['file_name']).toList(),
      })}');

      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Task updated successfully',
          'task_id': taskId,
        };
      } else {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update task',
          'task_id': taskId,
        };
      }
    } catch (e) {
      print('Error updating task: $e');
      return {
        'success': false,
        'message': 'Error updating task: $e',
        'task_id': taskId,
      };
    }
  }
} 