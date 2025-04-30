import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

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
  bool _isRegistered = false;

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

  void connect(String username) {
    print('🔌 Connecting socket for user: $username');
    // Disconnect existing socket if any
    disconnect();

    _currentUsername = username;
    _isRegistered = false;
    
    if (_serverUrl == null) {
      print('🔌 Error: Server URL not initialized');
      return;
    }

    _socket = IO.io(
      _serverUrl!,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .setReconnectionAttempts(5)
        .setReconnectionDelay(3000)
        .setReconnectionDelayMax(5000)
        .setTimeout(20000)
        .disableAutoConnect()
        .build()
    );

    _setupSocketListeners();
    print('🔌 Connecting to socket server...');
    _socket!.connect();
  }

  void _setupSocketListeners() {
    _socket!.onConnect((_) {
      print('🔌 Socket connected successfully');
      connected.value = true;
      // Register user immediately after connection if not already registered
      if (!_isRegistered && _currentUsername != null) {
        registerUser(_currentUsername!);
      }
    });

    _socket!.onDisconnect((_) {
      print('🔌 Socket disconnected');
      connected.value = false;
      _isRegistered = false;
      // Only attempt to reconnect if we still have a username
      if (_currentUsername != null) {
        Future.delayed(Duration(seconds: 3), () {
          if (_socket != null && !_socket!.connected) {
            print('🔌 Attempting to reconnect...');
            _socket!.connect();
          }
        });
      }
    });

    _socket!.on('register_response', (data) {
      print('🔌 Received register response: $data');
      if (data['status'] == 'registered') {
        _isRegistered = true;
        print('🔌 Successfully registered user: ${data['username']}');
      }
    });

    _socket!.on('task_notification', (data) async {
      print('🔔 SocketService - Received task notification: $data');
      
      // Check if the current user is the sender
      final String? sender = data['sender'] ?? data['assigned_by'];
      final String? targetUser = data['target_user'] ?? data['assigned_to'];
      
      // Only play sound and vibrate if the current user is the target and not the sender
      if (targetUser == _currentUsername && sender != _currentUsername) {
        print('🔔 SocketService - Playing notification for target user: $targetUser');
        await _notificationService.handleNewNotification();
      }
      
      print('🔔 SocketService - Number of task notification listeners: ${_taskNotificationListeners.length}');
      for (var listener in _taskNotificationListeners) {
        try {
          print('🔔 SocketService - Calling notification listener');
          listener(data);
          print('🔔 SocketService - Successfully called notification listener');
        } catch (e) {
          print('❌ SocketService - Error in notification listener: $e');
        }
      }
    });

    _socket!.on('dashboard_update', (data) {
      print('📨 Received dashboard update: $data');
      print('📨 Number of dashboard update listeners: ${_dashboardUpdateListeners.length}');
      
      // Check if the current user is the sender
      final String? sender = data['updated_by'] ?? data['assigned_by'];
      
      // Process update even if current user is the sender to maintain consistency
      for (var listener in _dashboardUpdateListeners) {
        try {
          listener(data);
          print('📨 Successfully called dashboard update listener');
        } catch (e) {
          print('📨 Error in dashboard update listener: $e');
        }
      }
    });

    _socket!.onError((error) {
      print('❌ Socket error: $error');
    });

    _socket!.onConnectError((error) {
      print('❌ Socket connect error: $error');
      connected.value = false;
      _isRegistered = false;
      // Only attempt to reconnect if we still have a username
      if (_currentUsername != null) {
        Future.delayed(Duration(seconds: 3), () {
          if (_socket != null && !_socket!.connected) {
            print('🔌 Attempting to reconnect after error...');
            _socket!.connect();
          }
        });
      }
    });
  }

  void disconnect() {
    print('🔌 Disconnecting socket');
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _currentUsername = null;
    _isRegistered = false;
    connected.value = false;
    _taskNotificationListeners.clear();
    _dashboardUpdateListeners.clear();
  }

  void registerUser(String username) {
    if (_socket != null && _socket!.connected) {
      print('🔌 Registering user: $username');
      _socket!.emit('register', username);
    } else {
      print('🔌 Socket not connected, cannot register user');
      if (_socket == null) {
        print('🔌 Socket is null');
      } else {
        print('🔌 Socket connected status: ${_socket!.connected}');
      }
    }
  }

  void listenToTaskNotifications(Function(dynamic) onTaskNotification) {
    print('📨 Adding task notification listener');
    _taskNotificationListeners.add(onTaskNotification);
    print('📨 Current number of task notification listeners: ${_taskNotificationListeners.length}');
  }

  void listenToDashboardUpdates(Function(dynamic) onDashboardUpdate) {
    print('📨 Adding dashboard update listener');
    _dashboardUpdateListeners.add(onDashboardUpdate);
    print('📨 Current number of dashboard update listeners: ${_dashboardUpdateListeners.length}');
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
    if (_socket != null && !_socket!.connected && _currentUsername != null) {
      print('🔌 Manually attempting to reconnect...');
      _socket!.connect();
    } else {
      print('🔌 Cannot reconnect: socket=${_socket != null}, connected=${_socket?.connected}, username=$_currentUsername');
    }
  }

  void dispose() {
    print('🔌 Disposing socket service');
    disconnect();
  }
} 