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
    print('🔌 [Socket] Connecting socket for user: $username');
    // Disconnect existing socket if any
    disconnect();

    _currentUsername = username;
    _isRegistered = false;
    
    if (_serverUrl == null) {
      print('❌ [Socket] Error: Server URL not initialized');
      return;
    }

    print('🔌 [Socket] Creating socket connection to: $_serverUrl');
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
    print('🔌 [Socket] Attempting to connect to socket server...');
    _socket!.connect();

    // Add reconnection logic
    _socket!.onReconnect((_) {
      print('🔄 [Socket] Reconnected to server');
      _isRegistered = true;
      _notifyListeners('connection_status', {'status': 'connected'});
      _registerUser();
    });

    _socket!.onReconnectAttempt((attempt) {
      print('🔄 [Socket] Reconnection attempt $attempt');
    });

    _socket!.onReconnectError((error) {
      print('❌ [Socket] Reconnection error: $error');
    });

    _socket!.onReconnectFailed((_) {
      print('❌ [Socket] Reconnection failed after all attempts');
      _isRegistered = false;
      _notifyListeners('connection_status', {'status': 'disconnected'});
    });
  }

  void _setupSocketListeners() {
    print('🔌 [Socket] Setting up socket listeners...');
    _socket!
      ..onConnect((_) {
        print('✅ [Socket] Connected to server successfully');
        _isRegistered = true;
        _notifyListeners('connection_status', {'status': 'connected'});
        // Register user after connection
        _registerUser();
      })
      ..onDisconnect((_) {
        print('❌ [Socket] Disconnected from server');
        _isRegistered = false;
        _notifyListeners('connection_status', {'status': 'disconnected'});
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
        _notifyListeners('error', error);
      })
      ..onConnectError((error) {
        print('❌ [Socket] Connection error: $error');
        _isRegistered = false;
        // Attempt to reconnect after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentUsername != null && !_isRegistered) {
            print('🔄 [Socket] Attempting to reconnect after error...');
            reconnect();
          }
        });
      })
      ..on('register_response', (data) {
        print('📝 [Socket] Registration response: $data');
        _isRegistered = data['status'] == 'registered';
      })
      ..on('task_notification', (data) {
        print('📬 [Socket] Received task notification: $data');
        // Play sound and vibrate
        _notificationService.playNotificationSound();
        _notificationService.vibrate();
        // Notify listeners
        _notifyListeners('task_notification', data);
      })
      ..on('dashboard_update', (data) {
        print('📊 [Socket] Received dashboard update: $data');
        _notifyListeners('dashboard_update', data);
      });
    print('✅ [Socket] Socket listeners setup complete');
  }

  void _registerUser() {
    if (_socket != null && _currentUsername != null) {
      print('🔌 [Socket] Registering user: $_currentUsername');
      _socket!.emit('register', {'username': _currentUsername});
    }
  }

  void removeAllListeners() {
    if (_socket != null) {
      print('🔌 Removing all socket listeners');
      _socket!.clearListeners();
      _taskNotificationListeners.clear();
      _dashboardUpdateListeners.clear();
    }
  }

  void disconnect() {
    if (_socket != null) {
      print('🔌 Disconnecting socket');
      removeAllListeners();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isRegistered = false;
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

  void _notifyListeners(String event, dynamic data) {
    print('📢 [Socket] Notifying listeners for event: $event');
    if (event == 'task_notification') {
      print('📢 [Socket] Found ${_taskNotificationListeners.length} task notification listeners');
      for (var listener in _taskNotificationListeners) {
        print('📢 [Socket] Calling task notification listener with data: $data');
        listener(data);
      }
    } else if (event == 'dashboard_update') {
      print('📢 [Socket] Found ${_dashboardUpdateListeners.length} dashboard update listeners');
      for (var listener in _dashboardUpdateListeners) {
        print('📢 [Socket] Calling dashboard update listener with data: $data');
        listener(data);
      }
    } else if (event == 'connection_status') {
      connected.value = data['status'] == 'connected';
    } else if (event == 'error') {
      print('❌ [Socket] Error event received: $data');
    }
  }
} 