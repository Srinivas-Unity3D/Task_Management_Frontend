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
    if (_isConnecting) {
      print('🔌 Already attempting to connect...');
      return;
    }

    if (_socket?.connected ?? false) {
      print('🔌 Socket already connected');
      return;
    }

    _isConnecting = true;
    _currentUsername = username;

    try {
      print('🔌 Attempting to connect to socket...');
      
      _socket = IO.io(_serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'reconnectionAttempts': maxReconnectAttempts,
      });

      // Setup event handlers
      _socket!.onConnect((_) {
        print('🔌 Socket connected successfully');
        _isConnecting = false;
        _reconnectAttempts = 0;
        _startPingTimer();
        _registerUser();
      });

      _socket!.onDisconnect((_) {
        print('🔌 Socket disconnected');
        _stopPingTimer();
        _handleDisconnect();
      });

      _socket!.onError((error) {
        print('🔌 Socket error: $error');
        _handleError();
      });

      _socket!.on('task_notification', (data) {
        print('📨 Received task notification: $data');
        for (var listener in _taskNotificationListeners) {
          listener(data);
        }
      });

      // Connect socket
      _socket!.connect();
      
      // Wait for connection or timeout
      await _waitForConnection();
      
    } catch (e) {
      print('🔌 Error connecting to socket: $e');
      _isConnecting = false;
      _handleError();
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
    _isConnecting = false;
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: _reconnectAttempts + 1), () {
        _reconnectAttempts++;
        connect(_currentUsername!);
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
        print('🔌 Received register response: $data');
        if (data['status'] == 'registered') {
          print('🔌 Successfully registered user: $_currentUsername');
        }
      });
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

  void disconnect() {
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentUsername = null;
    _isConnecting = false;
    _reconnectAttempts = 0;
    _taskNotificationListeners.clear();
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
} 