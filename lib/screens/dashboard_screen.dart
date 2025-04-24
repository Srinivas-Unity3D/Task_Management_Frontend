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
import '../widgets/dashboard/side_menu.dart';
import '../widgets/dashboard/side_panel.dart';
import '../widgets/custom_text_field.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _apiService = ApiService();
  late User _user;
  TaskStats? _taskStats;
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Get the stored user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';
      final role = prefs.getString('role') ?? '';

      // Load user data
      _user = User(
        userId: '1',
        username: username,
        email: '$username@example.com',
        phone: '+1234567890',
        role: role,
        fcmToken: null,
      );

      // Fetch tasks from API
      final response = await _apiService.getTasks(username: username, role: role);
      if (response['success']) {
        final tasksJson = response['data'] as List;
        final tasks = tasksJson.map((task) => Task.fromJson(task)).toList();
        setState(() {
          _taskStats = TaskStats.fromTasks(tasks);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to load tasks'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading dashboard: $e'); // Add debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear all stored data
    await prefs.clear();
    
    if (mounted) {
      // Navigate to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SignInScreen(),
        ),
      );
    }
  }

  Widget _buildNotificationIcon({required bool hasUnreadNotifications}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.notifications_outlined,
              color: AppColors.accentCyan,
              size: 24,
            ),
          ),
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

  void _showSidePanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation1,
          curve: Curves.easeInOut,
        );
        return Stack(
          children: [
            // Backdrop for tap to dismiss
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // Side Panel
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: SidePanel(
                  onLogout: _handleLogout,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              )
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileSection(
                          user: _user,
                          onProfileTap: _showSidePanel,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'My Dashboard',
                              style: TextStyle(
                                color: AppColors.accentCyan,
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
                          count: _taskStats?.activeTasks.toString() ?? '0',
                          icon: Icons.assignment,
                          onTap: () {
                            // TODO: Navigate to active tasks
                          },
                        ),
                        const SizedBox(height: 16),
                        StatsCard(
                          title: 'In Progress',
                          count: _taskStats?.inProgressTasks.toString() ?? '0',
                          icon: Icons.trending_up,
                          iconColor: Colors.blue,
                          onTap: () {
                            // TODO: Navigate to in-progress tasks
                          },
                        ),
                        const SizedBox(height: 16),
                        StatsCard(
                          title: 'Completed',
                          count: _taskStats?.completedTasks.toString() ?? '0',
                          icon: Icons.check_circle,
                          iconColor: Colors.green,
                          onTap: () {
                            // TODO: Navigate to completed tasks
                          },
                        ),
                        const SizedBox(height: 16),
                        StatsCard(
                          title: 'Snoozed',
                          count: _taskStats?.snoozedTasks.toString() ?? '0',
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