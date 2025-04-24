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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      // Get the stored user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'Srinivas';
      final role = prefs.getString('role') ?? 'Developer';

      _user = User(
        userId: '1',
        username: username,
        email: '$username@example.com',
        phone: '+1234567890',
        role: role,
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
      ];

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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                                count: _taskStats.activeTasks.toString(),
                                icon: Icons.assignment,
                                onTap: () {
                                  // TODO: Navigate to active tasks
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
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}