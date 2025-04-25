import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attachment.dart';

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
    List<TaskAttachment>? attachments,
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
        if (audioNote != null) 'audio_note': audioNote,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
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

      final data = json.decode(response.body);
      
      if (response.statusCode == 201) {  // API returns 201 for successful creation
        return {
          'success': true,
          'message': data['message'] ?? 'Task created successfully',
          'task_id': data['task_id'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create task',
        };
      }
    } catch (e) {
      print('Error creating task: $e');
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
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
} 