import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/attachment.dart';
import '../models/task_assignment.dart';
import '../models/voice_note.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class CacheManager {
  // Static singleton instance
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // Lightweight cache storage
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamp = {};
  
  // Cache duration (adjust based on your needs)
  static const cacheDuration = Duration(minutes: 5);

  bool isDataValid(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamp.containsKey(key)) {
      return false;
    }
    
    final timestamp = _cacheTimestamp[key]!;
    return DateTime.now().difference(timestamp) < cacheDuration;
  }

  void setData(String key, dynamic data) {
    _cache[key] = data;
    _cacheTimestamp[key] = DateTime.now();
    
    // Cleanup old cache entries
    _cleanupCache();
  }

  dynamic getData(String key) {
    if (!isDataValid(key)) {
      _cache.remove(key);
      _cacheTimestamp.remove(key);
      return null;
    }
    return _cache[key];
  }

  void _cleanupCache() {
    final now = DateTime.now();
    final keysToRemove = _cacheTimestamp.keys
        .where((key) => now.difference(_cacheTimestamp[key]!) > cacheDuration)
        .toList();
    
    for (var key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamp.remove(key);
    }
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamp.clear();
  }
}

class ApiService {
  static const String baseUrl = 'http://134.209.149.12:5000';
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

  // Add getter for dio instance
  Dio get dio => _dio;

  // Initialize the CacheManager
  final CacheManager _cacheManager = CacheManager();

  // Add background sync controller
  final StreamController<void> _syncController = StreamController<void>.broadcast();
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Initialize background sync
  void initBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _syncController.add(null);
    });

    _syncController.stream.listen((_) {
      _performBackgroundSync();
    });
  }

  // Dispose background sync
  void disposeBackgroundSync() {
    _syncTimer?.cancel();
    _syncController.close();
  }

  // Perform background sync
  Future<void> _performBackgroundSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final role = prefs.getString('role');

      if (userId == null || role == null) {
        _isSyncing = false;
        return;
      }

      print('🔄 [SYNC] Starting background sync for user: $userId');

      // Get last sync timestamp
      final lastSync = prefs.getString('last_sync_timestamp') ?? '0';
      
      // Fetch only updates since last sync
      final response = await http.get(
        Uri.parse('$baseUrl/sync?user_id=$userId&last_sync=$lastSync'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updates = data['updates'] as List;
        
        // Update cache for each changed task
        for (var update in updates) {
          await updateTaskCache(userId, role);
        }

        // Store new sync timestamp
        await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
        print('✅ [SYNC] Background sync completed successfully');
      }
    } catch (e) {
      print('❌ [SYNC] Background sync failed: $e');
    } finally {
      _isSyncing = false;
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
      print('Attempting login for user: $username');
      
      // Get FCM token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token') ?? '';
      
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'username': username,
          'password': password,
          'fcm_token': fcmToken,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        // Store user data in SharedPreferences
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
    } on TimeoutException {
      print('Login request timed out');
      return {
        'success': false,
        'message': 'Connection timed out. Please check your internet connection.',
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
      // Generate cache key
      final cacheKey = 'tasks_${username}_${role}';
      print('🔍 [CACHE] Checking cache for key: $cacheKey');
      
      // Check cache first
      final cachedData = _cacheManager.getData(cacheKey);
      if (cachedData != null) {
        print('✅ [CACHE] Found cached data');
        return {
          'success': true,
          'data': cachedData,
        };
      }
      print('ℹ️ [CACHE] No cached data found, fetching from API');

      // Add retry logic
      int maxRetries = 3;
      int currentTry = 0;
      Duration retryDelay = const Duration(seconds: 1);

      while (currentTry < maxRetries) {
        try {
          print('🔍 [API] Fetching tasks for user: $username with role: $role (Attempt ${currentTry + 1})');
          
          final response = await _dio.get(
            '/tasks',
            queryParameters: {
              'username': username,
              'role': role,
            },
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
            ),
          );

          print('📥 [API] Tasks response status: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = response.data;
            print('💾 [CACHE] Caching new data');
            _cacheManager.setData(cacheKey, data);
            return {
              'success': true,
              'data': data,
            };
          }
          
          // If we get here, it means we got a response but it wasn't 200
          print('⚠️ [API] Received non-200 status code: ${response.statusCode}');
          currentTry++;
          
        } catch (e) {
          print('❌ [API] Error during fetch attempt ${currentTry + 1}: $e');
          currentTry++;
          
          if (currentTry < maxRetries) {
            print('🔄 [API] Retrying in ${retryDelay.inSeconds} seconds...');
            await Future.delayed(retryDelay);
            // Increase delay for next retry
            retryDelay *= 2;
          }
        }
      }
      
      // If we have cached data but failed to refresh, use cached data
      if (cachedData != null) {
        print('⚠️ [API] Failed to fetch fresh data, using cached data');
        return {
          'success': true,
          'data': cachedData,
        };
      }
      
      // If all retries failed and no cache, return empty list
      print('⚠️ [API] All retry attempts failed, returning empty list');
      return {
        'success': true,
        'data': [],
      };

    } catch (e) {
      print('❌ [API] Fatal error loading tasks: $e');
      return {
        'success': true,
        'data': [],
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
    List<Map<String, dynamic>>? audioNotes,
    List<File>? attachments,
    Map<String, dynamic>? alarmSettings,
  }) async {
    try {
      // Convert attachments to base64
      List<Map<String, dynamic>> attachmentData = [];
      if (attachments != null) {
        for (var file in attachments) {
          if (await file.exists()) {
            List<int> fileBytes = await file.readAsBytes();
            String base64File = base64Encode(fileBytes);
            String fileName = file.path.split('/').last;
            String fileType = fileName.split('.').last;
            
            attachmentData.add({
              'file_name': fileName,
              'file_type': fileType,
              'file_data': base64File,
            });
          }
        }
      }

      // Get assignee's FCM token from server (use /get_fcm_token with POST)
      String? assigneeFcmToken;
      try {
        final tokenResponse = await http.post(
          Uri.parse('$baseUrl/get_fcm_token'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({'username': assignedTo}),
        );
        if (tokenResponse.statusCode == 200) {
          assigneeFcmToken = json.decode(tokenResponse.body)['fcm_token'];
        }
      } catch (_) {}

      // Prepare the request body
      final taskData = {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'assigned_by': assignedBy,
        'deadline': deadline.toIso8601String(),
        'priority': priority,
        'status': status,
        'audio_notes': audioNotes,
        'alarm_settings': alarmSettings,
        'attachments': attachmentData,
        'assignee_fcm_token': assigneeFcmToken,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(taskData),
      ).timeout(const Duration(seconds: 10));

      print('📤 [API] Create task response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final newTask = responseData['task'];
        
        // Update cache for both users
        await updateTaskCache(assignedTo, assignedBy);
        
        // Clear assignments cache for both users to force refresh
        final assigneeAssignmentsKey = 'task_assignments_$assignedTo';
        final assignerAssignmentsKey = 'task_assignments_$assignedBy';
        _cacheManager.getData(assigneeAssignmentsKey)?.clear();
        _cacheManager.getData(assignerAssignmentsKey)?.clear();
        
        // Trigger background sync
        _syncController.add(null);
        
        return {
          'success': true,
          'message': responseData['message'] ?? 'Task created successfully',
          'task': newTask,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create task: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ [API] Error creating task: $e');
      return {
        'success': false,
        'message': 'Failed to create task: $e',
      };
    }
  }

  Future<List<VoiceNote>> getTaskVoiceNotes(String taskId) async {
    try {
      print('📞 [API] Fetching voice notes for task: $taskId');
      final response = await _dio.get('/tasks/$taskId/audio');
      print('✅ [API] Voice notes response status: [36m[1m${response.statusCode}[0m');
      print('✅ [API] Voice notes response data: ${response.data}');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Patch: Ensure each VoiceNote has taskId set
        return data.map((json) {
          final note = VoiceNote.fromJson(json);
          return note.taskId == null ? VoiceNote(
            id: note.id,
            taskId: taskId,
            filePath: note.filePath,
            audioData: note.audioData,
            createdBy: note.createdBy,
            createdAt: note.createdAt,
            duration: note.duration,
            fileName: note.fileName,
          ) : note;
        }).toList();
      } else if (response.statusCode == 404) {
        print('ℹ️ [API] No voice notes found for task');
        return [];
      } else {
        throw Exception('Failed to fetch voice notes: ${response.statusMessage}');
      }
    } catch (e) {
      print('❌ [API] Error getting task voice notes: $e');
      return [];
    }
  }

  Future<String?> downloadVoiceNote(VoiceNote voiceNote) async {
    try {
      if (voiceNote.id == null) {
        print('❌ Voice note ID is null');
        return null;
      }

      // Use the filePath from the voice note metadata
      final filePathFromMeta = voiceNote.filePath;
      if (filePathFromMeta == null || filePathFromMeta.isEmpty) {
        print('❌ Voice note filePath is null or empty');
        return null;
      }

      // Create directory for audio files if it doesn't exist
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // Always use .wav extension for audio files
      final fileName = '${voiceNote.id}.wav';
      final localFilePath = '${audioDir.path}/$fileName';

      // Download the actual audio file from the backend
      final url = '${ApiService.baseUrl}/$filePathFromMeta';
      print('⬇️ Downloading audio from: $url');
      final response = await _dio.download(
        url,
        localFilePath,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: Duration(minutes: 2),
          sendTimeout: Duration(minutes: 2),
        ),
      );

      if (response.statusCode == 200) {
        final file = File(localFilePath);
        final fileSize = await file.length();
        print('✅ Voice note downloaded successfully: $localFilePath');
        print('📏 Downloaded file size: $fileSize bytes');
        // Print first 32 bytes for debugging
        final bytes = await file.openRead(0, fileSize < 32 ? fileSize : 32).toList();
        final flatBytes = bytes.expand((b) => b).toList();
        print('🔎 First bytes: ${flatBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        return localFilePath;
      } else {
        print('❌ Failed to download voice note: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading voice note: $e');
      return null;
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
    final cacheKey = 'task_assignments_$userId';
    
    try {
      // Try to get cached data first
      final cachedData = _cacheManager.getData(cacheKey);
      if (cachedData != null) {
        print('✅ [CACHE] Found cached task assignments');
        return (cachedData as List).map((json) => TaskAssignment.fromJson(json)).toList();
      }

      // Add retry logic
      int maxRetries = 3;
      int currentTry = 0;
      Duration retryDelay = const Duration(seconds: 1);

      while (currentTry < maxRetries) {
        try {
          print('🔍 [API] Fetching task assignments for user: $userId (Attempt ${currentTry + 1})');
          
          final response = await _dio.get(
            '/tasks/assignments/$userId',
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
            ),
          );

          print('📥 [API] Task assignments response status: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = response.data['assignments'] as List;
            
            // Cache the successful response
            _cacheManager.setData(cacheKey, data);
            
            return data.map((json) => TaskAssignment.fromJson(json)).toList();
          }
          
          // If we get here, it means we got a response but it wasn't 200
          print('⚠️ [API] Received non-200 status code: ${response.statusCode}');
          currentTry++;
          
        } catch (e) {
          print('❌ [API] Error during fetch attempt ${currentTry + 1}: $e');
          currentTry++;
          
          if (currentTry < maxRetries) {
            print('🔄 [API] Retrying in ${retryDelay.inSeconds} seconds...');
            await Future.delayed(retryDelay);
            // Increase delay for next retry
            retryDelay *= 2;
          }
        }
      }
      
      // If we have cached data but failed to refresh, use cached data
      if (cachedData != null) {
        print('⚠️ [API] Failed to fetch fresh data, using cached data');
        return (cachedData as List).map((json) => TaskAssignment.fromJson(json)).toList();
      }
      
      // If all retries failed and no cache, return empty list
      print('⚠️ [API] All retry attempts failed, returning empty list');
      return [];

    } catch (e) {
      print('❌ [API] Fatal error fetching task assignments: $e');
      print('🔍 [API] Fetching task assignments for user: $userId');
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/assignments/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📥 [API] Task assignments response status: ${response.statusCode}');
      print('📥 [API] Task assignments response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final assignments = data['assignments'] as List;
        
        // Cache the data
        _cacheManager.setData(cacheKey, assignments);
        
        return assignments.map((json) => TaskAssignment.fromJson(json)).toList();
      } else {
        print('❌ [API] Failed to fetch task assignments: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [API] Error fetching task assignments: $e');
      return [];
    }
  }

  // Add method to force refresh assignments
  Future<List<TaskAssignment>> refreshTaskAssignments(String userId) async {
    final cacheKey = 'task_assignments_$userId';
    
    try {
      print('🔄 [API] Force refreshing task assignments for user: $userId');
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/assignments/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['assignments'] as List;
        
        // Update cache
        _cacheManager.setData(cacheKey, data);
        
        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, json.encode(data));
        
        print('💾 [CACHE] Updated task assignments in cache and storage');
        return data.map((json) => TaskAssignment.fromJson(json)).toList();
      }
      
      // If refresh fails, return cached data
      final cachedData = _cacheManager.getData(cacheKey);
      if (cachedData != null) {
        return (cachedData as List).map((json) => TaskAssignment.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('❌ [API] Error refreshing task assignments: $e');
      // Return cached data on error
      final cachedData = _cacheManager.getData(cacheKey);
      if (cachedData != null) {
        return (cachedData as List).map((json) => TaskAssignment.fromJson(json)).toList();
      }
      return [];
    }
  }

  // Add method to clear all cache
  void clearCache() {
    print('🧹 [CACHE] Clearing all cache');
    _cacheManager.clearCache();
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
    List<Map<String, dynamic>>? audioNotes,
    List<File>? attachments,
    Map<String, dynamic>? alarmSettings,
    List<String>? existingAttachmentIds,
  }) async {
    try {
      print('📤 [API] Updating task $taskId with data:');
      print('Title: $title');
      print('Description: $description');
      print('AssignedTo: $assignedTo');
      print('AssignedBy: $assignedBy');
      print('Priority: $priority');
      print('Status: $status');
      print('Audio Notes: ${audioNotes?.length ?? 0}');
      print('New Attachments: ${attachments?.length ?? 0}');
      print('Existing Attachments: ${existingAttachmentIds?.length ?? 0}');

      // Get assignee's FCM token from server (use /get_fcm_token with POST)
      String? assigneeFcmToken;
      try {
        final tokenResponse = await _dio.post(
          '/get_fcm_token',
          data: {'username': assignedTo},
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true,
          ),
        );
        if (tokenResponse.statusCode == 200) {
          assigneeFcmToken = tokenResponse.data['fcm_token'];
        }
      } catch (_) {}

      // Prepare the request body
      final taskData = {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'assigned_by': assignedBy,
        'deadline': deadline.toIso8601String(),
        'priority': priority,
        'status': status,
        'updated_by': assignedBy,
        'audio_notes': audioNotes,
        'alarm_settings': alarmSettings,
        'assignee_fcm_token': assigneeFcmToken,
        'existing_attachment_ids': existingAttachmentIds,
      };

      // Convert attachments to base64 if present
      if (attachments != null && attachments.isNotEmpty) {
        List<Map<String, dynamic>> attachmentData = [];
        for (var file in attachments) {
          if (await file.exists()) {
            List<int> fileBytes = await file.readAsBytes();
            String base64File = base64Encode(fileBytes);
            String fileName = file.path.split('/').last;
            String fileType = fileName.split('.').last;
            
            attachmentData.add({
              'file_name': fileName,
              'file_type': fileType,
              'file_data': base64File,
            });
          }
        }
        taskData['attachments'] = attachmentData;
      }

      final response = await _dio.put(
        '/tasks/$taskId',
        data: taskData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      print('📤 [API] Update task response status: ${response.statusCode}');
      print('📤 [API] Update task response data: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        
        // Clear all cache to force refresh
        clearCache();
        
        // Trigger background sync
        _syncController.add(null);
        
        return {
          'success': true,
          'message': responseData['message'] ?? 'Task updated successfully',
          'task': responseData,
        };
      } else {
        print('❌ [API] Failed to update task: ${response.statusCode}');
        print('❌ [API] Error message: ${response.data}');
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to update task: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ [API] Error updating task: $e');
      return {
        'success': false,
        'message': 'Failed to update task: $e',
      };
    }
  }

  // Helper method to update task cache
  Future<void> updateTaskCache(String username, String role) async {
    final cacheKey = 'tasks_${username}_${role}';
    try {
      _cacheManager.getData(cacheKey)?.clear();
      final response = await _dio.get(
        '/tasks',
        queryParameters: {
          'username': username,
          'role': role,
        },
      );
      if (response.statusCode == 200) {
        final tasks = response.data;
        _cacheManager.setData(cacheKey, tasks);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, json.encode(tasks));
        print('💾 [CACHE] Updated tasks cache for user: $username, role: $role');
      }
    } catch (e) {
      print('❌ [CACHE] Error updating task cache: $e');
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

  // Helper to get auth token from SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
} 