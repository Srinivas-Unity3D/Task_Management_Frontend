import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskmanagement/services/notification_firebase_service.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';

import '../models/attachment.dart';
import '../models/task_assignment.dart';
import '../models/voice_note.dart';
import 'send_notification_service.dart';

// Add this class to handle SSL certificates
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class ApiService {
  static const String baseUrl = 'https://134.209.149.12';
  // static const String baseUrl = 'http://10.20.0.248:5000';
  late Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  bool _isRefreshing = false;
  Completer<bool>? _refreshTokenCompleter;
  final _authService = AuthService();
  
  ApiService() {
    // Set up SSL certificate handling
    HttpOverrides.global = MyHttpOverrides();
    _initDio();
    setupFcmTokenRefreshListener();
    _loadTokensFromStorage();
  }
  
  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status! < 500, // Allow all responses under 500
    ));
    
    // Add SSL certificate handling for Dio
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };
    
    // Add request interceptor to always get fresh token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        print('🌐 [API] Making request to: ${options.path}');
        print('🌐 [API] Request method: ${options.method}');
        print('🌐 [API] Headers: ${options.headers}');
        
        // Set content type appropriately but don't overwrite multipart/form-data
        if (options.contentType != 'multipart/form-data') {
          options.contentType = 'application/json';
        }
        
        // Always get a fresh token for each request - for all content types including multipart/form-data
        try {
          final token = await _authService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print('🔐 [API] Added token to request (${token.substring(0, min(15, token.length))}...)');
          } else {
            print('⚠️ [API] No token available for request');
          }
        } catch (e) {
          print('❌ [API] Error getting token: $e');
        }
        
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('📥 [API] Response from: ${response.requestOptions.path}');
        print('📥 [API] Status code: ${response.statusCode}');
        return handler.next(response);
      },
      onError: (DioException error, handler) async {
        print('❌ [API] Error on request: ${error.requestOptions.path}');
        print('❌ [API] Error type: ${error.type}');
        print('❌ [API] Error message: ${error.message}');
        
        if (error.response != null) {
          print('❌ [API] Error response: ${error.response?.data}');
          print('❌ [API] Error status code: ${error.response?.statusCode}');
        }
        
        // Handle authentication errors
        if (error.response?.statusCode == 401) {
          print('🔄 [API] Unauthorized error - attempting token refresh');
          final refreshed = await refreshToken();
          if (refreshed) {
            print('✅ [API] Token refreshed, retrying request');
            return handler.resolve(await _retry(error.requestOptions));
          }
        }
        
        return handler.next(error);
      },
    ));
  }
  
  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    
    if (_accessToken != null) {
      options.headers?['Authorization'] = 'Bearer $_accessToken';
    }
    
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
  
  Future<void> _loadTokensFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
      
      // Validate loaded tokens
      if (_accessToken != null && !await _authService.isLoggedIn()) {
        print('🔑 [API] Loaded token is expired, attempting refresh');
        if (!await refreshToken()) {
          await clearTokens();
        }
      }
    } catch (e) {
      print('❌ [API] Error loading tokens from storage: $e');
      await clearTokens();
    }
  }
  
  Future<void> _saveTokensToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null) {
        await prefs.setString('access_token', _accessToken!);
        await _authService.setToken(_accessToken!);
      }
      if (_refreshToken != null) {
        await prefs.setString('refresh_token', _refreshToken!);
      }
    } catch (e) {
      print('❌ [API] Error saving tokens to storage: $e');
    }
  }
  
  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await _authService.clearToken();
      _accessToken = null;
      _refreshToken = null;
    } catch (e) {
      print('❌ [API] Error clearing tokens: $e');
    }
  }

  Future<bool> refreshToken() async {
    if (_isRefreshing) {
      return _refreshTokenCompleter?.future ?? Future.value(false);
    }
    
    _isRefreshing = true;
    _refreshTokenCompleter = Completer<bool>();

    try {
      if (_refreshToken == null) {
        print('❌ [API] Cannot refresh token: No refresh token available');
        _refreshTokenCompleter?.complete(false);
        return false;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/refresh_token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_refreshToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        await _saveTokensToStorage();
        print('✅ [API] Tokens refreshed successfully');
        _refreshTokenCompleter?.complete(true);
        return true;
      } else {
        print('❌ [API] Failed to refresh token: ${response.statusCode}');
        await clearTokens();
        _refreshTokenCompleter?.complete(false);
        return false;
      }
    } catch (e) {
      print('❌ [API] Error refreshing token: $e');
      await clearTokens();
      _refreshTokenCompleter?.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshTokenCompleter = null;
    }
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
      // print('Updating FCM token for username: $username');
      // print('FCM token to update: $fcmToken');
      //
      // // First get the user_id for the username using POST request
      // final response = await http.post(
      //   Uri.parse('$baseUrl/get_fcm_token'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Accept': 'application/json',
      //   },
      //   body: json.encode({
      //     'username': username,
      //   }),
      // );
      //
      // print('Get FCM token response status: ${response.statusCode}');
      // print('Get FCM token response body: ${response.body}');
      //
      // if (response.statusCode != 200) {
      //   print('Failed to get user ID. Status: ${response.statusCode}, Body: ${response.body}');
      //   return {
      //     'success': false,
      //     'message': 'Failed to get user ID',
      //   };
      // }
      //
      // final userData = json.decode(response.body);
      // final userId = userData['user_id'];
      //
      // if (userId == null) {
      //   print('User ID not found in response: ${response.body}');
      //   return {
      //     'success': false,
      //     'message': 'User ID not found',
      //   };
      // }
      //
      // print('Retrieved user ID: $userId');

      // Now update the FCM token
      final updateResponse = await http.post(
        Uri.parse('$baseUrl/update_fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'username': username,
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
      print('🔑 [Login] Attempting login for user: $username');

      // Get stored FCM token
      final prefs = await SharedPreferences.getInstance();
      final storedFcmToken = prefs.getString('fcm_token');
      print('📱 [Login] Stored FCM token: $storedFcmToken');

      // Always get fresh FCM token from device
      final freshFcmToken = await NotificationFirebaseService().getDeviceToken();
      print('📱 [Login] Fresh FCM token from device: $freshFcmToken');

      // If we got a fresh token and it's different from stored token, update it
      if (freshFcmToken != null && freshFcmToken.isNotEmpty) {
        if (storedFcmToken != freshFcmToken) {
          print('📱 [Login] FCM token has changed, updating...');
          await prefs.setString('fcm_token', freshFcmToken);
        }
      }

      // Configure SSL for development
      HttpOverrides.global = MyHttpOverrides();

      print('🔑 [Login] Sending login request to: $baseUrl/login');
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

      print('🔑 [Login] Response status: ${response.statusCode}');
      print('🔑 [Login] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Store user data in SharedPreferences
        if (data['user_id'] != null) {
          await prefs.setString('user_id', data['user_id'].toString());
        }
        if (data['username'] != null) {
          await prefs.setString('username', data['username']);
        }
        if (data['role'] != null) {
          await prefs.setString('role', data['role']);
        }
        
        // Store JWT tokens
        if (data['access_token'] != null) {
          _accessToken = data['access_token'];
          _refreshToken = data['refresh_token'];
          await _saveTokensToStorage();
          print('🔑 [Login] JWT tokens stored successfully');
        }

        // Always update FCM token in backend after successful login
        if (freshFcmToken != null && freshFcmToken.isNotEmpty) {
          print('📱 [Login] Updating FCM token in backend after successful login');
          final updateResult = await updateFcmToken(username, freshFcmToken);
          print('📱 [Login] FCM token update result: $updateResult');
        } else {
          print('📱 [Login] No FCM token available to update after login');
        }

        return {
          'success': true,
          'data': data,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Invalid username or password',
        };
      } else {
        print('❌ [Login] Server error: ${response.statusCode}');
        print('❌ [Login] Error response: ${response.body}');
        return {
          'success': false,
          'message': 'Server error occurred. Please try again.',
        };
      }
    } on TimeoutException {
      print('❌ [Login] Request timed out');
      return {
        'success': false,
        'message': 'Connection timed out. Please check your internet connection.',
      };
    } on SocketException catch (e) {
      print('❌ [Login] Network error: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your internet connection.',
      };
    } catch (e, stackTrace) {
      print('❌ [Login] Error: $e');
      print('❌ [Login] Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'An error occurred during login. Please try again.',
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

          // print('📥 [API] Tasks response status: ${response.statusCode}');
          // print('📥 [API] Tasks response body: ${response.body}');

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

  Future<Map<String, dynamic>> createTask({
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
      print('🔄 [API] Creating task: title=$title, assignedTo=$assignedTo, status=$status');
      if (alarmSettings != null) {
        print('⏰ [API] Alarm settings: $alarmSettings');
      }
      
      // Create task data
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

      // Use _dio instead of http for automatic JWT token handling
      final response = await _dio.post(
        '/tasks',
        data: taskData,
      );

      print('📤 [API] Create task response status: ${response.statusCode}');
      print('📤 [API] Create task response data: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = response.data;
        return {
          'success': true,
          'message': 'Task created successfully',
          'task_id': responseData['task_id']
        };
      } else {
        print('❌ [API] Failed to create task: ${response.statusCode} - ${response.data}');
        return {
          'success': false,
          'message': 'Failed to create task: ${response.statusMessage}'
        };
      }
    } on DioException catch (e) {
      print('❌ [API] Dio error creating task: ${e.message}');
      print('❌ [API] Error type: ${e.type}');
      print('❌ [API] Error response: ${e.response?.data}');
      return {
        'success': false,
        'message': 'Network error: ${e.message}'
      };
    } catch (e) {
      print('❌ [API] Error creating task: $e');
      return {
        'success': false,
        'message': 'Failed to create task: $e'
      };
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
        
        // Ensure filename has .wav extension
        String fileName = voiceNote.fileName.isNotEmpty ? voiceNote.fileName : 'voice_note.wav';
        if (!fileName.toLowerCase().endsWith('.wav')) {
          final nameParts = fileName.split('.');
          fileName = '${nameParts.first}.wav';
        }
        
        final file = File('${tempDir.path}/$fileName');
        final bytes = base64.decode(voiceNote.audioData!);
        await file.writeAsBytes(bytes);
        print('✅ [API] Voice note saved successfully');
        return file.path;
      }

      // Always use the API endpoint for download, not the filePath
      if (voiceNote.taskId != null && voiceNote.id != null) {
        final url = '/api/tasks/${voiceNote.taskId}/audio/${voiceNote.id}/download';
        print('📥 [API] Downloading voice note from: $url');
        
        // Get token for authentication
        final token = await _authService.getToken();
        if (token == null) {
          print('⚠️ [API] No token available for voice note download');
          if (await refreshToken()) {
            return downloadVoiceNote(voiceNote); // Retry after token refresh
          }
          return null;
        }
        
        try {
          // Use Dio for authenticated download
          final response = await _dio.get(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {
                'Authorization': 'Bearer $token',
              },
            ),
          );
          
          if (response.statusCode == 200) {
            print('✅ [API] Voice note downloaded successfully');
            final tempDir = await getTemporaryDirectory();
            
            // Ensure filename has .wav extension
            String fileName = voiceNote.fileName.isNotEmpty ? voiceNote.fileName : 'voice_note.wav';
            if (!fileName.toLowerCase().endsWith('.wav')) {
              final nameParts = fileName.split('.');
              fileName = '${nameParts.first}.wav';
            }
            
            final file = File('${tempDir.path}/$fileName');
            await file.writeAsBytes(response.data);
            return file.path;
          } else {
            print('⚠️ [API] Failed to download voice note: ${response.statusCode}');
            return null;
          }
        } catch (e) {
          print('⚠️ [API] Error downloading voice note: $e');
          return null;
        }
      }
      
      // Fallback to using the file path directly (not recommended, but kept for compatibility)
      if (voiceNote.filePath != null && voiceNote.filePath!.isNotEmpty) {
        print('⚠️ [API] Using direct file path (not recommended): ${voiceNote.filePath}');
        return voiceNote.filePath;
      }
      
      print('⚠️ [API] No way to download voice note: missing ID or file path');
      return null;
    } catch (e) {
      print('❌ [API] Error downloading voice note: $e');
      return null;
    }
  }

  Future<List<Attachment>> getTaskAttachments(String taskId) async {
    try {
      print('📎 [API] Fetching attachments for task: $taskId');
      
      final response = await _dio.get('/tasks/$taskId/attachments');
      
      print('📎 [API] Attachments response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        if (response.data['success'] == true && response.data['attachments'] != null) {
          final List<dynamic> attachments = response.data['attachments'];
          print('📎 [API] Found ${attachments.length} attachments');
          return attachments
              .map((attachment) => Attachment.fromJson(attachment))
              .toList();
        } else {
          print('📎 [API] No attachments found or invalid response format');
          return [];
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [API] Authentication failed when fetching attachments');
        // Try refreshing token and retry once
        if (await refreshToken()) {
          return getTaskAttachments(taskId); // Recursive call after token refresh
        }
        throw Exception('Authentication failed when fetching attachments');
      } else {
        print('❌ [API] Failed to fetch attachments: ${response.statusCode}');
        throw Exception('Failed to fetch attachments');
      }
    } catch (e) {
      print('❌ [API] Error getting task attachments: $e');
      if (e.toString().contains('401')) {
        // Handle 401 errors that might be thrown as exceptions
        if (await refreshToken()) {
          return getTaskAttachments(taskId);
        }
      }
      throw Exception('Failed to fetch attachments: $e');
    }
  }

  Future<String> downloadAttachment(String attachmentId) async {
    try {
      print('📥 [API] Downloading attachment: $attachmentId');
      
      // Get token for authentication
      final token = await _authService.getToken();
      if (token == null) {
        print('⚠️ [API] No token available for attachment download');
        throw Exception('Authentication failed');
      }
      
      final response = await _dio.get(
        '/attachments/$attachmentId/download',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final bytes = response.data as List<int>;
        final tempDir = await getTemporaryDirectory();
        final fileName = response.headers
                .value('content-disposition')
                ?.split('filename=')
                .last ??
            'attachment_$attachmentId';
        print('📥 [API] Saving attachment as: $fileName');
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        print('✅ [API] Attachment downloaded and saved');
        return file.path;
      } else if (response.statusCode == 401) {
        print('⚠️ [API] Authentication failed when downloading attachment');
        // Try refreshing token and retry once
        if (await refreshToken()) {
          return downloadAttachment(attachmentId); // Recursive call after token refresh
        }
        throw Exception('Authentication failed when downloading attachment');
      } else {
        print('❌ [API] Failed to download attachment: ${response.statusCode}');
        throw Exception('Failed to download attachment: ${response.statusCode}');
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
      
      if (response.statusCode == 200) {
        print('✅ [API] Audio notes found: ${response.data}');
        
        // Ensure all file paths are properly formatted for client use
        if (response.data is List) {
          for (var note in response.data) {
            if (note is Map<String, dynamic> && note.containsKey('file_path')) {
              // Store the original file_path for reference
              note['original_file_path'] = note['file_path'];
              
              // Create a proper API endpoint URL for downloading
              if (note.containsKey('audio_id')) {
                note['download_url'] = '/api/tasks/$taskId/audio/${note['audio_id']}/download';
              }
            }
          }
        }
        
        return {'success': true, 'data': response.data};
      } else if (response.statusCode == 404) {
        print('ℹ️ [API] No audio note found for task');
        return {'success': true, 'data': null};
      } else if (response.statusCode == 401) {
        print('⚠️ [API] Authentication failed when fetching audio notes');
        // Try refreshing token and retry once
        if (await refreshToken()) {
          return getAudioNote(taskId); // Recursive call after token refresh
        }
        return {
          'success': false,
          'message': 'Authentication failed when fetching audio notes'
        };
      } else {
        print('❌ [API] Failed to fetch audio note: ${response.statusCode}');
        return {'success': false, 'message': 'Failed to fetch audio note'};
      }
    } on DioException catch (e) {
      print('❌ [API] Dio error fetching audio note: ${e.message}');
      if (e.response?.statusCode == 401) {
        // Try refreshing token and retry once
        if (await refreshToken()) {
          return getAudioNote(taskId);
        }
      }
      return {'success': false, 'message': 'Error fetching audio note: ${e.message}'};
    } catch (e) {
      print('❌ [API] Error fetching audio note: $e');
      return {'success': false, 'message': 'Error fetching audio note: $e'};
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

  Future<Map<String, dynamic>> updateTask({
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
    required String currentUser,
  }) async {
    try {
      print('🔄 [API] Updating task: $taskId');
      print('📝 [API] Task data: title=$title, assignedTo=$assignedTo, status=$status');
      if (alarmSettings != null) {
        print('⏰ [API] Alarm settings: $alarmSettings');
      }
      
      // Create task data
      final taskData = {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'assigned_by': assignedBy,
        'deadline': deadline.toIso8601String(),
        'priority': priority,
        'status': status,
        'updated_by': currentUser,
        'audio_note': audioNote,
        'alarm_settings': alarmSettings,
        'attachments': attachments,
        'currentUser': currentUser
      };

      // Use _dio instead of http for automatic JWT token handling
      final response = await _dio.put(
        '/tasks/$taskId',
        data: taskData,
      );

      print('📤 [API] Update task response status: ${response.statusCode}');
      print('📤 [API] Update task response data: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        return {
          'success': true,
          'message': 'Task updated successfully',
          'task_id': responseData['task_id']
        };
      } else {
        print('❌ [API] Failed to update task: ${response.statusCode} - ${response.data}');
        return {
          'success': false,
          'message': 'Failed to update task: ${response.statusMessage}'
        };
      }
    } on DioException catch (e) {
      print('❌ [API] Dio error updating task: ${e.message}');
      print('❌ [API] Error type: ${e.type}');
      print('❌ [API] Error response: ${e.response?.data}');
      return {
        'success': false,
        'message': 'Network error: ${e.message}'
      };
    } catch (e) {
      print('❌ [API] Error updating task: $e');
      return {
        'success': false,
        'message': 'Failed to update task: $e'
      };
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
      
      // Calculate next trigger time based on start date, time and frequency
      final startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        int.parse(startTime.split(':')[0]),
        int.parse(startTime.split(':')[1]),
      );
      
      final data = {
        'task_id': taskId,
        'assigned_to': assignedTo,
        'start_date': startDate.toIso8601String().split('T')[0],
        'start_time': startTime,
        'frequency': frequency,
        'is_active': true,
        'next_trigger': startDateTime.toIso8601String(),
      };
      
      final response = await _dio.post(
        '/alarms/register',
        data: data,
      );
      
      print('⏰ [API] Register alarm response status: ${response.statusCode}');
      print('⏰ [API] Register alarm response data: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
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
          'error': response.data,
        };
      }
    } catch (e) {
      print('❌ [API] Error registering alarm: $e');
      return {
        'success': false,
        'message': 'Error registering alarm: $e',
      };
    }
  }

  // Add a logout method
  Future<bool> logout() async {
    try {
      await clearTokens();
      
      // Clear user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('username');
      await prefs.remove('role');
      
      print('User logged out successfully');
      return true;
    } catch (e) {
      print('Error during logout: $e');
      return false;
    }
  }

  // Add HTTP Request helper with auth header
  Future<http.Response> _authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParams,
    );
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Add auth header if we have a token
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    http.Response response;
    
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported method: $method');
    }
    
    // Handle 401 responses manually (can't use interceptor with http package)
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await refreshToken();
      if (refreshed) {
        // Update the headers with new token
        headers['Authorization'] = 'Bearer $_accessToken';
        
        // Retry the request
        switch (method.toUpperCase()) {
          case 'GET':
            return await http.get(uri, headers: headers);
          case 'POST':
            return await http.post(
              uri,
              headers: headers,
              body: body != null ? json.encode(body) : null,
            );
          case 'PUT':
            return await http.put(
              uri,
              headers: headers,
              body: body != null ? json.encode(body) : null,
            );
          case 'DELETE':
            return await http.delete(uri, headers: headers);
          default:
            throw Exception('Unsupported method: $method');
        }
      }
    }
    
    return response;
  }

  Future<Map<String, dynamic>?> uploadFile(FormData formData) async {
    try {
      print('📤 [API] Uploading file with form data: ${formData.fields}');
      
      // Get auth token specifically for file upload
      final token = await _authService.getToken();
      if (token == null) {
        print('⚠️ [API] No token available for file upload');
        // Try refreshing token
        if (await refreshToken()) {
          print('✅ [API] Token refreshed, retrying upload');
          return uploadFile(formData); // Recursive call after token refresh
        }
        return {'success': false, 'message': 'Authentication failed'};
      }
      
      final response = await _dio.post(
        '/upload',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
          contentType: 'multipart/form-data',
          validateStatus: (status) => status! < 500,
        ),
      );

      print('📤 [API] Upload response status: ${response.statusCode}');
      
      if (response.statusCode == 401) {
        print('⚠️ [API] Authentication failed during file upload');
        // Try refreshing token and retry once
        if (await refreshToken()) {
          return uploadFile(formData); // Recursive call after token refresh
        }
        return {'success': false, 'message': 'Authentication failed during upload'};
      }
      
      if (response.statusCode != 200) {
        print('❌ [API] Upload failed with status: ${response.statusCode}');
        print('❌ [API] Error response: ${response.data}');
        return {'success': false, 'message': 'File upload failed'};
      }

      return response.data;
    } catch (e) {
      print('❌ [API] Error uploading file: $e');
      return {'success': false, 'message': 'Connection error during upload'};
    }
  }

  Future<Map<String, dynamic>?> getTaskById(String taskId) async {
    try {
      final response = await _dio.get('/tasks/$taskId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['task'];
      }
      return null;
    } catch (e) {
      print('❌ [ApiService] Error fetching task by ID: $e');
      return null;
    }
  }
}
