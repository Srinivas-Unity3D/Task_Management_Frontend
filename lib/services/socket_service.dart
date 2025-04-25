import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  IO.Socket? _socket;
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  String? _currentUsername;
  String? _serverUrl;
  final List<Function(dynamic)> _taskNotificationListeners = [];
  final List<Function(dynamic)> _dashboardUpdateListeners = [];

  // Singleton pattern
  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  void init(String serverUrl) {
    print('🔌 Initializing socket service with URL: $serverUrl');
    _serverUrl = serverUrl;
    // Don't connect immediately, wait for login
  }

  void connect(String username) {
    print('🔌 Connecting socket for user: $username');
    // Disconnect existing socket if any
    disconnect();

    _currentUsername = username;
    
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

    // Set up event listeners
    _socket!.onConnect((_) {
      print('🔌 Socket connected successfully');
      connected.value = true;
      // Register user immediately after connection
      registerUser(_currentUsername!);
    });

    _socket!.onDisconnect((_) {
      print('🔌 Socket disconnected');
      connected.value = false;
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

    _socket!.onError((error) {
      print('🔌 Socket error: $error');
      connected.value = false;
    });

    _socket!.onConnectError((error) {
      print('🔌 Socket connect error: $error');
      connected.value = false;
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

    // Set up event handlers for notifications
    _socket!.on('connect_response', (data) {
      print('🔌 Received connect response: $data');
    });

    _socket!.on('register_response', (data) {
      print('🔌 Received register response: $data');
    });

    _socket!.on('task_notification', (data) {
      print('📨 Received task notification: $data');
      print('📨 Number of task notification listeners: ${_taskNotificationListeners.length}');
      for (var listener in _taskNotificationListeners) {
        try {
          listener(data);
          print('📨 Successfully called task notification listener');
        } catch (e) {
          print('📨 Error in task notification listener: $e');
        }
      }
    });

    _socket!.on('dashboard_update', (data) {
      print('📨 Received dashboard update: $data');
      print('📨 Number of dashboard update listeners: ${_dashboardUpdateListeners.length}');
      for (var listener in _dashboardUpdateListeners) {
        try {
          listener(data);
          print('📨 Successfully called dashboard update listener');
        } catch (e) {
          print('📨 Error in dashboard update listener: $e');
        }
      }
    });

    print('🔌 Connecting to socket server...');
    _socket!.connect();
  }

  void disconnect() {
    print('🔌 Disconnecting socket');
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _currentUsername = null;
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