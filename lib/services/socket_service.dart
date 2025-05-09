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
    print('🔌 [Socket] Current connection status: ${_socket?.connected ?? false}');
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
        .setTransports(['websocket', 'polling'])
        .enableReconnection()
        .setReconnectionAttempts(5)
        .setReconnectionDelay(3000)
        .setReconnectionDelayMax(5000)
        .setTimeout(20000)
        .enableAutoConnect()
        .setQuery({'username': username})
        .setExtraHeaders({
          'username': username,
          'Content-Type': 'application/json',
        })
        .build()
    );

    _setupSocketListeners();
    print('🔌 [Socket] Attempting to connect to socket server...');
    _socket!.connect();

    // Verify connection after a short delay
    Future.delayed(Duration(seconds: 2), () {
      print('🔌 [Socket] Connection status after 2 seconds: ${_socket?.connected ?? false}');
      print('🔌 [Socket] Is registered: $_isRegistered');
      if (_socket?.connected ?? false) {
        print('✅ [Socket] Connection verified, registering user...');
        _registerUser();
      } else {
        print('🔄 [Socket] Connection failed, attempting to reconnect...');
        reconnect();
      }
    });
  }

  void _setupSocketListeners() {
    print('🔌 [Socket] Setting up socket listeners...');
    print('🔌 [Socket] Current connection status: ${_socket?.connected ?? false}');
    print('🔌 [Socket] Current task notification listeners: ${_taskNotificationListeners.length}');
    print('🔌 [Socket] Current dashboard update listeners: ${_dashboardUpdateListeners.length}');
    
    _socket!
      ..onConnect((_) {
        print('✅ [Socket] Connected to server successfully');
        print('✅ [Socket] Socket ID: ${_socket?.id}');
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
        print('❌ [Socket] Error stack trace: ${StackTrace.current}');
        _notifyListeners('error', error);
      })
      ..onConnectError((error) {
        print('❌ [Socket] Connection error: $error');
        print('❌ [Socket] Connection error stack trace: ${StackTrace.current}');
        _isRegistered = false;
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
      })
      ..on('connect_timeout', (error) {
        print('❌ [Socket] Connection timeout: $error');
      })
      ..on('error', (error) {
        print('❌ [Socket] Socket error event: $error');
      })
      ..on('reconnect', (attempt) {
        print('🔄 [Socket] Reconnected after $attempt attempts');
        _isRegistered = true;
        _notifyListeners('connection_status', {'status': 'connected'});
        _registerUser();
      })
      ..on('reconnect_attempt', (attempt) {
        print('🔄 [Socket] Reconnection attempt $attempt');
      })
      ..on('reconnect_error', (error) {
        print('❌ [Socket] Reconnection error: $error');
      })
      ..on('reconnect_failed', (error) {
        print('❌ [Socket] Reconnection failed after all attempts: $error');
        _isRegistered = false;
        _notifyListeners('connection_status', {'status': 'disconnected'});
      })
      ..on('register_response', (data) {
        print('📝 [Socket] Registration response: $data');
        _isRegistered = data['status'] == 'registered';
        if (_isRegistered) {
          print('✅ [Socket] User registered successfully');
        } else {
          print('❌ [Socket] User registration failed');
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
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isRegistered = false;
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
    if (_socket != null && !_socket!.connected && _currentUsername != null) {
      print('🔌 Manually attempting to reconnect...');
      print('🔌 [Socket] Current connection status: ${_socket?.connected ?? false}');
      print('🔌 [Socket] Current username: $_currentUsername');
      
      // Try to reconnect with a new socket instance
      disconnect();
      connect(_currentUsername!);
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