import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math';
import 'notification_service.dart';
import 'dart:async';
import 'auth_service.dart';
import 'api_service.dart';

// Add this class to handle self-signed certificates
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class SocketService {
  static final SocketService _instance = SocketService._internal();
  
  /// Get the singleton instance of SocketService
  static SocketService get instance => _instance;
  
  IO.Socket? _socket;
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  String? _currentUsername;
  String? _serverUrl;
  final List<Function(dynamic)> _taskNotificationListeners = [];
  final List<Function(dynamic)> _dashboardUpdateListeners = [];
  final _notificationService = NotificationService();
  final _apiService = ApiService();
  bool _isRegistered = false;
  bool _isConnecting = false;
  Timer? _heartbeatTimer;
  Timer? _tokenRefreshTimer;

  // Private constructor
  SocketService._internal();

  // Factory constructor that returns singleton instance
  factory SocketService() {
    return _instance;
  }

  void init(String serverUrl) async {
    print('🔌 Initializing socket service with URL: $serverUrl');
    // Convert http:// to ws:// and https:// to wss://
    if (serverUrl.startsWith('http://')) {
      _serverUrl = serverUrl.replaceFirst('http://', 'ws://');
    } else if (serverUrl.startsWith('https://')) {
      _serverUrl = serverUrl.replaceFirst('https://', 'wss://');
    } else {
      _serverUrl = serverUrl;
    }
    print('🔌 Converted socket URL: $_serverUrl');
    
    // Set up SSL certificate handling for both development and release
    HttpOverrides.global = DevHttpOverrides();
    
    await _notificationService.initialize();
    _startTokenRefreshTimer();
  }

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    // Check token every 5 minutes
    _tokenRefreshTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      if (_socket?.connected ?? false) {
        final authService = AuthService();
        if (!(await authService.isLoggedIn())) {
          print('🔑 [Socket] Token expired, refreshing...');
          if (await _apiService.refreshToken()) {
            print('🔑 [Socket] Token refreshed, reconnecting socket...');
            reconnect();
          } else {
            print('❌ [Socket] Token refresh failed, disconnecting...');
            disconnect();
          }
        }
      }
    });
  }

  Future<void> connect(String username) async {
    if (_isConnecting) {
      print('🔌 [Socket] Already attempting to connect, skipping...');
      return;
    }

    print('🔌 [Socket] Connecting socket for user: $username');
    print('🔌 [Socket] Current connection status: ${_socket?.connected ?? false}');
    print('🔌 [Socket] Server URL: $_serverUrl');
    
    // Check if already connected with same username
    if (_socket != null && _socket!.connected && _currentUsername == username) {
      final authService = AuthService();
      if (await authService.isLoggedIn()) {
        print('✅ [Socket] Already connected with valid token, reusing connection');
        _isRegistered = true;
        connected.value = true;
        _notifyListeners('connection_status', {'status': 'connected'});
        _registerUser();
        return;
      } else {
        print('🔑 [Socket] Token expired, refreshing connection...');
        disconnect();
      }
    }
    
    // Disconnect existing socket if any
    disconnect();

    _currentUsername = username;
    _isRegistered = false;
    _isConnecting = true;
    
    if (_serverUrl == null) {
      print('❌ [Socket] Error: Server URL not initialized');
      _isConnecting = false;
      return;
    }

    // Get the JWT token
    String? token;
    try {
      final authService = AuthService();
      token = await authService.getToken();
      
      // If token is null or expired, try to refresh it
      if (token == null || !(await authService.isLoggedIn())) {
        print('🔑 [Socket] Token invalid or expired, attempting refresh...');
        if (await _apiService.refreshToken()) {
          token = await authService.getToken();
        }
      }
      
      if (token == null) {
        print('❌ [Socket] No valid token available after refresh attempt');
        _isConnecting = false;
        return;
      }
      
      print('🔑 [Socket] Using token: ${token.substring(0, min(10, token.length))}...');
    } catch (e) {
      print('❌ [Socket] Error getting auth token: $e');
      _isConnecting = false;
      return;
    }

    // Configure SSL security for development
    if (!kReleaseMode) {
      // Set up the HTTP/HTTPS client to accept self-signed certificates
      HttpOverrides.global = DevHttpOverrides();
      print('🔒 [Socket] SSL certificate validation disabled for development');
    }

    try {
      print('🔌 [Socket] Creating socket connection to: $_serverUrl');
      print('🔌 [Socket] Connection options: transports=websocket, auth enabled');
      
      final options = IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setExtraHeaders({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        })
        .enableForceNew()
        .enableReconnection()
        .setReconnectionAttempts(10)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setTimeout(20000)
        .setPath('/socket.io')  // Add explicit path
        .build();

      print('🔌 [Socket] Options configured: ${options.toString()}');
      
      _socket = IO.io(_serverUrl!, options);

      print('🔌 [Socket] Socket instance created, setting up listeners...');
      _setupSocketListeners();
      print('🔌 [Socket] Attempting to connect...');
      _socket!.connect();
      
      // Verify connection after a short delay
      Future.delayed(Duration(seconds: 2), () {
        final isConnected = _socket?.connected ?? false;
        print('🔌 [Socket] Connection status after 2 seconds: $isConnected');
        print('🔌 [Socket] Socket ID: ${_socket?.id}');
        print('🔌 [Socket] Is registered: $_isRegistered');
        print('🔌 [Socket] Socket engine state: ${_socket?.io.engine?.readyState}');
        
        if (isConnected) {
          print('✅ [Socket] Connection verified, registering user...');
          _registerUser();
        } else {
          print('🔄 [Socket] Connection failed, attempting to reconnect...');
          // Try a second approach before giving up
          _socket!.connect();
          
          // Check again after a short delay
          Future.delayed(Duration(seconds: 2), () {
            final secondAttemptConnected = _socket?.connected ?? false;
            print('🔌 [Socket] Second attempt connection status: $secondAttemptConnected');
            print('🔌 [Socket] Socket engine state: ${_socket?.io.engine?.readyState}');
            if (!secondAttemptConnected) {
              print('🔄 [Socket] Second connection attempt failed, recreating socket...');
              reconnect();
            }
          });
        }
        _isConnecting = false;
      });
    } catch (e, stackTrace) {
      print('❌ [Socket] Error creating socket connection: $e');
      print('❌ [Socket] Error stack trace: $stackTrace');
      _isConnecting = false;
      // Attempt to reconnect after a delay
      Future.delayed(Duration(seconds: 5), () {
        if (_currentUsername != null && !_isRegistered) {
          print('🔄 [Socket] Attempting to reconnect after error...');
          _isConnecting = false; // Reset flag to allow reconnection
          reconnect();
        }
      });
    }
  }

  void _setupSocketListeners() {
    print('🔌 [Socket] Setting up socket listeners...');
    print('🔌 [Socket] Current connection status: ${_socket?.connected ?? false}');
    print('🔌 [Socket] Current task notification listeners: ${_taskNotificationListeners.length}');
    print('🔌 [Socket] Current dashboard update listeners: ${_dashboardUpdateListeners.length}');
    
    if (_socket == null) {
      print('❌ [Socket] Cannot setup listeners: socket is null');
      return;
    }

    try {
      _socket!
        ..onConnect((_) {
          print('✅ [Socket] Connected to server successfully');
          print('✅ [Socket] Socket ID: ${_socket?.id}');
          _isRegistered = true;
          connected.value = true;
          _notifyListeners('connection_status', {'status': 'connected'});
          // Register user after connection
          _registerUser();
          // Start heartbeat after successful connection
          _startHeartbeat();
        })
        ..onDisconnect((_) {
          print('❌ [Socket] Disconnected from server');
          _isRegistered = false;
          connected.value = false;
          _notifyListeners('connection_status', {'status': 'disconnected'});
          // Stop heartbeat on disconnect
          _stopHeartbeat();
          // Attempt to reconnect after a delay
          Future.delayed(const Duration(seconds: 5), () {
            if (_currentUsername != null && !_isRegistered) {
              print('🔄 [Socket] Attempting to reconnect...');
              reconnect();
            }
          });
        })
        ..onError((error) {
          print('❌ [Socket] Error: $error');
          print('❌ [Socket] Error stack trace: ${StackTrace.current}');
          connected.value = false;
          _notifyListeners('error', error);
        })
        ..onConnectError((error) {
          print('❌ [Socket] Connection error: $error');
          print('❌ [Socket] Connection error stack trace: ${StackTrace.current}');
          _isRegistered = false;
          connected.value = false;
          // Attempt to reconnect after a delay
          Future.delayed(const Duration(seconds: 5), () {
            if (_currentUsername != null && !_isRegistered) {
              print('🔄 [Socket] Attempting to reconnect after error...');
              reconnect();
            }
          });
        })
        ..on('connect_error', (error) {
          print('❌ [Socket] Connection error event: $error');
          print('❌ [Socket] Connection error stack trace: ${StackTrace.current}');
          connected.value = false;
        })
        ..on('connect_timeout', (error) {
          print('❌ [Socket] Connection timeout: $error');
          connected.value = false;
        })
        ..on('error', (error) {
          print('❌ [Socket] Socket error event: $error');
          connected.value = false;
        })
        ..on('reconnect', (attempt) {
          print('🔄 [Socket] Reconnected after $attempt attempts');
          _isRegistered = true;
          connected.value = true;
          _notifyListeners('connection_status', {'status': 'connected'});
          _registerUser();
        })
        ..on('reconnect_attempt', (attempt) {
          print('🔄 [Socket] Reconnection attempt $attempt');
        })
        ..on('reconnect_error', (error) {
          print('❌ [Socket] Reconnection error: $error');
          connected.value = false;
        })
        ..on('reconnect_failed', (error) {
          print('❌ [Socket] Reconnection failed after all attempts: $error');
          _isRegistered = false;
          connected.value = false;
          _notifyListeners('connection_status', {'status': 'disconnected'});
        })
        ..on('register_response', (data) {
          print('📝 [Socket] Registration response: $data');
          _isRegistered = data['status'] == 'registered';
          if (_isRegistered) {
            print('✅ [Socket] User registered successfully');
            connected.value = true;
          } else {
            print('❌ [Socket] User registration failed');
            connected.value = false;
          }
        })
        ..on('task_notification', (data) {
          print('📬 [Socket] Received task notification: $data');
          print('📬 [Socket] Current username: $_currentUsername');
          print('📬 [Socket] Number of task notification listeners: ${_taskNotificationListeners.length}');
          // Notify listeners
          _notifyListeners('task_notification', data);
        })
        ..on('dashboard_update', (data) {
          print('📊 [Socket] Received dashboard update: $data');
          print('📊 [Socket] Number of dashboard update listeners: ${_dashboardUpdateListeners.length}');
          _notifyListeners('dashboard_update', data);
        });
      print('✅ [Socket] Socket listeners setup complete');
    } catch (e) {
      print('❌ [Socket] Error setting up socket listeners: $e');
      print('❌ [Socket] Error stack trace: ${StackTrace.current}');
    }
  }

  void _registerUser() {
    if (_socket != null && _currentUsername != null) {
      print('🔌 [Socket] Registering user: $_currentUsername');
      print('🔌 [Socket] Socket connected: ${_socket?.connected}');
      print('🔌 [Socket] Socket ID: ${_socket?.id}');
      _socket!.emit('register', {'username': _currentUsername});
    } else {
      print('❌ [Socket] Cannot register user: socket=${_socket != null}, username=$_currentUsername');
    }
  }

  void removeAllListeners() {
    if (_socket != null) {
      print('🔌 Removing all socket listeners');
      print('🔌 Current task notification listeners before removal: ${_taskNotificationListeners.length}');
      print('🔌 Current dashboard update listeners before removal: ${_dashboardUpdateListeners.length}');
      
      // Only clear socket event listeners, not our callback listeners
      _socket!.clearListeners();
      
      // Re-setup socket listeners to maintain connection
      _setupSocketListeners();
      
      print('🔌 Task notification listeners after removal: ${_taskNotificationListeners.length}');
      print('🔌 Dashboard update listeners after removal: ${_dashboardUpdateListeners.length}');
    }
  }

  void disconnect() {
    if (_socket != null) {
      print('🔌 Disconnecting socket');
      removeAllListeners();
      _stopHeartbeat();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isRegistered = false;
      _isConnecting = false;
    }
  }

  void listenToTaskNotifications(Function(dynamic) onTaskNotification) {
    print('📨 Adding task notification listener');
    print('📨 Current listeners before adding: ${_taskNotificationListeners.length}');
    
    if (!_taskNotificationListeners.contains(onTaskNotification)) {
      _taskNotificationListeners.add(onTaskNotification);
      print('📨 Current number of task notification listeners: ${_taskNotificationListeners.length}');
    } else {
      print('📨 Task notification listener already exists');
    }
  }

  void listenToDashboardUpdates(Function(dynamic) onDashboardUpdate) {
    print('📨 Adding dashboard update listener');
    print('📨 Current listeners before adding: ${_dashboardUpdateListeners.length}');
    
    if (!_dashboardUpdateListeners.contains(onDashboardUpdate)) {
      _dashboardUpdateListeners.add(onDashboardUpdate);
      print('📨 Current number of dashboard update listeners: ${_dashboardUpdateListeners.length}');
    } else {
      print('📨 Dashboard update listener already exists');
    }
  }

  void removeTaskNotificationListener(Function(dynamic) listener) {
    _taskNotificationListeners.remove(listener);
    print('📨 Removed task notification listener. Remaining: ${_taskNotificationListeners.length}');
  }

  void removeDashboardUpdateListener(Function(dynamic) listener) {
    _dashboardUpdateListeners.remove(listener);
    print('📨 Removed dashboard update listener. Remaining: ${_dashboardUpdateListeners.length}');
  }

  bool isConnected() {
    final connected = _socket?.connected ?? false;
    print('🔌 Socket connection status: $connected');
    return connected;
  }

  void reconnect() {
    if (_socket != null && !_socket!.connected && _currentUsername != null && !_isConnecting) {
      print('🔌 Manually attempting to reconnect...');
      _isConnecting = true; // Set flag to prevent concurrent reconnection attempts
      
      try {
        print('🔌 [Socket] Current connection status: ${_socket?.connected ?? false}');
        print('🔌 [Socket] Current username: $_currentUsername');
        
        // Check if the socket engine is completely closed
        if (_socket!.connected == false && _socket!.io.engine != null && 
            (_socket!.io.engine!.readyState != "open" && _socket!.io.engine!.readyState != "opening")) {
          print('🔌 Socket engine not open, creating new connection');
          disconnect();
          connect(_currentUsername!);
        } else {
          print('🔌 Socket engine still potentially viable, trying internal reconnect');
          _socket!.connect(); // Try to use socket.io's reconnect mechanism
          
          // Check reconnection status after a delay
          Future.delayed(Duration(seconds: 2), () {
            if (!(_socket?.connected ?? false)) {
              print('🔌 Internal reconnect failed, creating new connection');
              disconnect();
              connect(_currentUsername!);
            }
            _isConnecting = false;
          });
        }
      } catch (e) {
        print('❌ Error during reconnection: $e');
        print('❌ Error stack trace: ${StackTrace.current}');
        _isConnecting = false;
        
        // Safe fallback - create a new connection after a delay
        Future.delayed(Duration(seconds: 3), () {
          disconnect();
          if (_currentUsername != null) {
            connect(_currentUsername!);
          }
        });
      }
    } else {
      print('🔌 Cannot reconnect: socket=${_socket != null}, connected=${_socket?.connected}, username=$_currentUsername, isConnecting=$_isConnecting');
      
      // Reset connecting flag if it's stuck
      if (_isConnecting && (_socket == null || _currentUsername == null)) {
        _isConnecting = false;
      }
    }
  }

  void dispose() {
    print('🔌 Disposing socket service');
    _stopHeartbeat();
    disconnect();
  }

  // Start sending heartbeats to server
  void _startHeartbeat() {
    // Stop any existing heartbeat
    _stopHeartbeat();
    
    print('💓 [Socket] Starting heartbeat mechanism');
    // Send heartbeat every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_socket != null && _socket!.connected) {
        print('💓 [Socket] Sending heartbeat');
        try {
          _socket!.emit('heartbeat', {});
        } catch (e) {
          print('❌ [Socket] Error sending heartbeat: $e');
        }
      } else {
        print('❌ [Socket] Cannot send heartbeat: socket=${_socket != null}, connected=${_socket?.connected}');
        // If socket is disconnected, stop the heartbeat and try to reconnect
        if (_socket != null && !_socket!.connected && _currentUsername != null) {
          print('🔄 [Socket] Lost connection, attempting to reconnect...');
          _stopHeartbeat();
          reconnect();
        }
      }
    });
  }
  
  // Stop sending heartbeats
  void _stopHeartbeat() {
    if (_heartbeatTimer != null) {
      print('💓 [Socket] Stopping heartbeat mechanism');
      _heartbeatTimer!.cancel();
      _heartbeatTimer = null;
    }
  }

  void _notifyListeners(String event, dynamic data) {
    print('📢 [Socket] Notifying listeners for event: $event');
    if (event == 'task_notification') {
      print('📢 [Socket] Found ${_taskNotificationListeners.length} task notification listeners');
      for (var listener in _taskNotificationListeners) {
        print('📢 [Socket] About to call task notification listener');
        try {
          listener(data);
          print('✅ [Socket] Successfully called task notification listener');
        } catch (e) {
          print('❌ [Socket] Error calling task notification listener: $e');
          print('❌ [Socket] Error stack trace: ${StackTrace.current}');
        }
      }
    } else if (event == 'dashboard_update') {
      print('📢 [Socket] Found ${_dashboardUpdateListeners.length} dashboard update listeners');
      for (var listener in _dashboardUpdateListeners) {
        print('📢 [Socket] About to call dashboard update listener');
        try {
          listener(data);
          print('✅ [Socket] Successfully called dashboard update listener');
        } catch (e) {
          print('❌ [Socket] Error calling dashboard update listener: $e');
          print('❌ [Socket] Error stack trace: ${StackTrace.current}');
        }
      }
    } else if (event == 'connection_status') {
      connected.value = data['status'] == 'connected';
    } else if (event == 'error') {
      print('❌ [Socket] Error event received: $data');
    }
  }
} 