import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attachment.dart';
import '../models/task_assignment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://134.209.149.12:5000';

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
    List<String>? attachments,
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

  // Add method to download attachment
  Future<Map<String, dynamic>> getAttachment(String attachmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attachments/$attachmentId'),
        headers: {
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
          'message': 'Failed to download attachment',
        };
      }
    } catch (e) {
      print('Error downloading attachment: $e');
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // Add method to get audio note
  Future<Map<String, dynamic>> getAudioNote(String taskId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/$taskId/audio'),
        headers: {
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
          'message': 'Failed to download audio note',
        };
      }
    } catch (e) {
      print('Error downloading audio note: $e');
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
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
} 