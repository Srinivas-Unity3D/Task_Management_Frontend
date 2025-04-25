import 'package:flutter/material.dart';
import '../widgets/notification_badge.dart';
import '../services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _socketService = SocketService();
  String? _username;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _socketService.listenToTaskNotifications(_handleNewNotification);
  }

  @override
  void dispose() {
    _socketService.removeTaskNotificationListener(_handleNewNotification);
    super.dispose();
  }

  void _handleNewNotification(dynamic data) {
    if (mounted) {
      setState(() {
        _notificationCount++;
      });
    }
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username != null) {
      setState(() => _username = username);
      _socketService.connect(username);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _socketService.disconnect();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Task Management',
          style: TextStyle(
            color: Color(0xFF7DF9FF),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          NotificationBadge(count: _notificationCount),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Welcome, ${_username ?? "User"}!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
} 