import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'dart:async';

typedef TaskNotificationCallback = void Function(dynamic data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  
  /// Get the singleton instance of SocketService
  static SocketService get instance => _instance;
  
  IO.Socket? _socket;
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  String? _currentUsername;
  String? _serverUrl;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  final List<TaskNotificationCallback> _taskNotificationListeners = [];
  final List<Function(dynamic)> _dashboardUpdateListeners = [];
  final _notificationService = NotificationService();
  bool _isRegistered = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  bool _isLoggedOut = true;
  final List<Function(String)> _uiRefreshListeners = [];

  // Private constructor
  SocketService._internal();

  // Factory constructor that returns singleton instance
  factory SocketService() {
    return _instance;
  }

  void init(String serverUrl) async {
    print('🔌 Initializing socket service with URL: $serverUrl');
    _serverUrl = serverUrl;
    await _notificationService.initialize();
  }

  Future<void> connect(String username) async {
    if (_isLoggedOut) {
      print('🔌 Cannot connect: User is logged out');
      return;
    }

    if (_isConnecting) {
      print('🔌 Already attempting to connect...');
      return;
    }

    if (_socket?.connected ?? false) {
      print('🔌 Already connected');
      return;
    }

    _isConnecting = true;
    _currentUsername = username;

    try {
      print('🔌 Attempting to connect to socket...');
      
      // Only attempt connection if not logged out
      if (!_isLoggedOut) {
        _socket = IO.io(_serverUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'reconnection': false,
        });

        _socket!.onConnect((_) {
          if (_isLoggedOut) {
            _socket?.disconnect();
            return;
          }
          print('🔌 Socket connected successfully');
          _isConnecting = false;
          _reconnectAttempts = 0;
          connected.value = true;
          _registerUser();
        });

        _socket!.onDisconnect((_) {
          print('🔌 Socket disconnected');
          connected.value = false;
          if (!_isLoggedOut) {
            _handleDisconnect();
          }
        });

        _socket!.onError((error) {
          print('🔌 Socket error: $error');
          connected.value = false;
          if (!_isLoggedOut) {
            _handleError();
          }
        });

        _socket!.on('task_notification', (data) {
          print('📨 Received task notification: $data');
          print('📨 Current listeners count: ${_taskNotificationListeners.length}');
          for (var listener in _taskNotificationListeners) {
            try {
              listener(data);
            } catch (e) {
              print('Error in task notification listener: $e');
            }
          }
        });

        _socket!.on('dashboard_update', (data) {
          print('📨 Received dashboard update: $data');
          print('📨 Current dashboard listeners count: ${_dashboardUpdateListeners.length}');
          for (var listener in _dashboardUpdateListeners) {
            try {
              listener(data);
            } catch (e) {
              print('Error in dashboard update listener: $e');
            }
          }
        });

        _socket!.connect();
      }
    } catch (e) {
      print('🔌 Error connecting to socket: $e');
      _isConnecting = false;
      connected.value = false;
    }
  }

  Future<void> _waitForConnection() {
    final completer = Completer<void>();
    Timer? timeoutTimer;

    void handleConnection(_) {
      timeoutTimer?.cancel();
      if (!completer.isCompleted) completer.complete();
    }

    // Set timeout
    timeoutTimer = Timer(const Duration(seconds: 5), () {
      _socket?.off('connect', handleConnection);
      if (!completer.isCompleted) {
        completer.completeError('Connection timeout');
      }
    });

    // Listen for connection
    _socket?.on('connect', handleConnection);

    return completer.future;
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_socket?.connected ?? false) {
        _socket!.emit('ping');
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _handleDisconnect() {
    if (_socket == null || _isLoggedOut) return;
    
    print('🔌 Socket disconnected');
    connected.value = false;
    
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: _reconnectAttempts * 2);
      print('🔌 Attempting reconnection in ${delay.inSeconds} seconds (attempt $_reconnectAttempts)');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        if (_currentUsername != null && !_isLoggedOut) {
          connect(_currentUsername!);
        }
      });
    }
  }

  void _handleError() {
    _isConnecting = false;
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: _reconnectAttempts + 1), () {
        _reconnectAttempts++;
        connect(_currentUsername!);
      });
    }
  }

  void _registerUser() {
    if (_currentUsername != null && (_socket?.connected ?? false)) {
      print('🔌 Registering user: $_currentUsername');
      _socket!.emit('register', {'username': _currentUsername});
      
      _socket!.once('register_response', (data) {
        print('🔌 Register response received: $data');
        if (data['status'] == 'registered') {
          _isRegistered = true;
          print('🔌 Successfully registered user: $_currentUsername');
        } else {
          print('🔌 Failed to register user: $_currentUsername');
          _isRegistered = false;
        }
      });
    } else {
      print('🔌 Cannot register user: socket not connected or username not set');
    }
  }

  void listenToTaskNotifications(TaskNotificationCallback callback) {
    if (!_taskNotificationListeners.contains(callback)) {
      _taskNotificationListeners.add(callback);
      print('📨 Adding task notification listener');
      print('📨 Current number of task notification listeners: ${_taskNotificationListeners.length}');
    }
  }

  void removeTaskNotificationListener(TaskNotificationCallback callback) {
    _taskNotificationListeners.remove(callback);
    print('📨 Removed task notification listener. Remaining: ${_taskNotificationListeners.length}');
  }

  void listenToUiRefresh(Function(String) onRefresh) {
    print('📨 Adding UI refresh listener');
    _uiRefreshListeners.add(onRefresh);
    print('📨 Current number of UI refresh listeners: ${_uiRefreshListeners.length}');
  }

  void removeUiRefreshListener(Function(String) listener) {
    _uiRefreshListeners.remove(listener);
    print('📨 Removed UI refresh listener. Remaining: ${_uiRefreshListeners.length}');
  }

  void broadcastUiRefresh(String screenName) {
    print('📨 Broadcasting UI refresh for screen: $screenName');
    for (var listener in _uiRefreshListeners) {
      try {
        listener(screenName);
      } catch (e) {
        print('Error in UI refresh listener: $e');
      }
    }
  }

  void disconnect() {
    try {
      print('🔌 Disconnecting socket service...');
      
      // Immediately set all flags to prevent any reconnection
      _isLoggedOut = true;
      _isConnecting = false;
      _reconnectAttempts = maxReconnectAttempts;
      connected.value = false;
      
      // Cancel timers immediately
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _pingTimer?.cancel();
      _pingTimer = null;

      // Clear all listeners and callbacks immediately
      _taskNotificationListeners.clear();
      _dashboardUpdateListeners.clear();
      _uiRefreshListeners.clear();

      // Force socket cleanup
      if (_socket != null) {
        try {
          _socket!.clearListeners();
          _socket!.destroy();
          _socket!.disconnect();
          _socket!.close();
        } catch (e) {
          print('⚠️ Socket cleanup error: $e');
        }
        _socket = null;
      }

      // Reset all state
      _currentUsername = null;
      _isRegistered = false;
      
      print('🔌 Socket service disconnected successfully');
    } catch (e) {
      print('❌ Error during socket disconnection: $e');
      // Force cleanup on error
      _socket = null;
      _currentUsername = null;
      connected.value = false;
    }
  }

  bool get isConnected => _socket?.connected ?? false;

  void listenToDashboardUpdates(Function(dynamic) onDashboardUpdate) {
    print('📨 Adding dashboard update listener');
    _dashboardUpdateListeners.add(onDashboardUpdate);
    print('📨 Current number of dashboard update listeners: ${_dashboardUpdateListeners.length}');
  }

  void removeDashboardUpdateListener(Function(dynamic) listener) {
    _dashboardUpdateListeners.remove(listener);
    print('📨 Removed dashboard update listener. Remaining: ${_dashboardUpdateListeners.length}');
  }

  void dispose() {
    print('🔌 Disposing socket service');
    disconnect();
  }

  void setLoggedIn() {
    _isLoggedOut = false;
    _reconnectAttempts = 0;
  }

  // Add method to emit task notifications
  void emitTaskNotification(Map<String, dynamic> taskData) {
    if (_socket != null && _socket!.connected) {
      print('📨 [Socket] Emitting task notification: $taskData');
      _socket!.emit('task_notification', taskData);
    } else {
      print('⚠️ [Socket] Cannot emit task notification: socket not connected');
      // Try to reconnect
      connect(_currentUsername ?? '');
    }
  }
} 