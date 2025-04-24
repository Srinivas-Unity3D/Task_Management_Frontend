import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dashboard/profile_section.dart';
import '../widgets/dashboard/navigation_menu.dart';
import '../widgets/dashboard/stats_card.dart';
import '../models/user.dart';
import '../models/task.dart';
import '../models/task_stats.dart';
import '../theme/colors.dart';
import 'sign_in_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late User _user;
  late TaskStats _taskStats;
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    // TODO: Replace with actual API call to check notifications
    // For now, we'll simulate no unread notifications
    setState(() {
      _hasUnreadNotifications = false;
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // TODO: Replace with actual API calls
      // Simulated data for now
      _user = User(
        userId: '1',
        username: 'Srinivas',
        email: 'srinivas@example.com',
        phone: '+1234567890',
        role: 'Developer',
        fcmToken: null,
      );

      // Simulate fetching tasks
      final List<Task> tasks = [
        Task(
          taskId: '1',
          title: 'Implement Dashboard',
          description: 'Create a responsive dashboard UI',
          deadline: DateTime.now().add(const Duration(days: 3)),
          priority: TaskPriority.high,
          status: TaskStatus.inProgress,
          assignedBy: '2',
          assignedTo: '1',
        ),
        // Add more sample tasks as needed
      ];

      // Calculate stats from tasks
      _taskStats = TaskStats.fromTasks(tasks);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildNotificationIcon({required bool hasUnreadNotifications}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Bell Icon centered in container
          const Center(
            child: Icon(
              Icons.notifications_outlined,
              color: Color(0xFF7DF9FF),
              size: 24,
            ),
          ),
          // Red dot only if there are unread notifications
          if (hasUnreadNotifications)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF7DF9FF),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          color: Colors.white,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
              color: const Color(0xFF0A0F1C),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileSection(user: _user),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Dashboard',
                        style: TextStyle(
                          color: Color(0xFF7DF9FF),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      _buildNotificationIcon(
                        hasUnreadNotifications: _hasUnreadNotifications,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  StatsCard(
                    title: 'Active Tasks',
                    count: _taskStats.activeTasks.toString(),
                    icon: Icons.assignment,
                    onTap: () {
                      // TODO: Navigate to active tasks list
                    },
                  ),
                  const SizedBox(height: 16),
                  StatsCard(
                    title: 'In Progress',
                    count: _taskStats.inProgressTasks.toString(),
                    icon: Icons.trending_up,
                    iconColor: Colors.blue,
                    onTap: () {
                      // TODO: Navigate to in-progress tasks
                    },
                  ),
                  const SizedBox(height: 16),
                  StatsCard(
                    title: 'Completed',
                    count: _taskStats.completedTasks.toString(),
                    icon: Icons.check_circle,
                    iconColor: Colors.green,
                    onTap: () {
                      // TODO: Navigate to completed tasks
                    },
                  ),
                  const SizedBox(height: 16),
                  StatsCard(
                    title: 'Snoozed',
                    count: _taskStats.snoozedTasks.toString(),
                    icon: Icons.snooze,
                    iconColor: Colors.orange,
                    onTap: () {
                      // TODO: Navigate to snoozed tasks
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}