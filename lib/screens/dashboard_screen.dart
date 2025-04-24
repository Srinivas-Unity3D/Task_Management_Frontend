import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dashboard/profile_section.dart';
import '../widgets/dashboard/navigation_menu.dart';
import '../widgets/dashboard/stats_card.dart';
import '../models/user.dart';
import '../models/task.dart';
import '../models/task_stats.dart';
import '../models/view_state.dart';
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
  ViewState _currentView = ViewState.dashboard;
  List<Task> _userTasks = [];

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
        _userTasks = tasksJson.map((task) => Task.fromJson(task)).toList();
        setState(() {
          _taskStats = TaskStats.fromTasks(_userTasks);
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

  void _switchView(ViewState newView) {
    setState(() {
      _currentView = newView;
    });
  }

  Widget _buildDashboardView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
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
          onTap: () => _switchView(ViewState.myTasks),
        ),
        const SizedBox(height: 16),
        StatsCard(
          title: 'In Progress',
          count: _taskStats?.inProgressTasks.toString() ?? '0',
          icon: Icons.trending_up,
          iconColor: Colors.blue,
          onTap: () => _switchView(ViewState.myTasks),
        ),
        const SizedBox(height: 16),
        StatsCard(
          title: 'Completed',
          count: _taskStats?.completedTasks.toString() ?? '0',
          icon: Icons.check_circle,
          iconColor: Colors.green,
          onTap: () => _switchView(ViewState.myTasks),
        ),
        const SizedBox(height: 16),
        StatsCard(
          title: 'Snoozed',
          count: _taskStats?.snoozedTasks.toString() ?? '0',
          icon: Icons.snooze,
          iconColor: Colors.orange,
          onTap: () => _switchView(ViewState.myTasks),
        ),
      ],
    );
  }

  Widget _buildMyTasksView() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _userTasks.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Tasks',
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
          );
        }

        final task = _userTasks[index - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority Indicator Dot
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.priority == TaskPriority.high 
                      ? AppColors.highPriority 
                      : AppColors.mediumPriority,
                ),
              ),
              const SizedBox(width: 12),
              // Task Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due ${_formatDate(task.deadline)}',
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF392F41),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  task.status.name.toUpperCase(),
                  style: TextStyle(
                    color: task.status == TaskStatus.completed 
                        ? AppColors.completed 
                        : AppColors.pending,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'History',
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
        const SizedBox(height: 24),
        // Add your history view here
      ],
    );
  }

  Widget _buildAssignTasksView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Assign Tasks',
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
        const SizedBox(height: 24),
        // Add your assign tasks view here
      ],
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case ViewState.dashboard:
        return _buildDashboardView();
      case ViewState.myTasks:
        return _buildMyTasksView();
      case ViewState.history:
        return _buildHistoryView();
      case ViewState.assignTasks:
        return _buildAssignTasksView();
    }
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
            : Column(
                children: [
                  // Profile Section at top
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: ProfileSection(
                      user: _user,
                      onProfileTap: _showSidePanel,
                      onMyTasksPressed: () => _switchView(ViewState.myTasks),
                      onHistoryPressed: () => _switchView(ViewState.history),
                      onAssignTasksPressed: () => _switchView(ViewState.assignTasks),
                    ),
                  ),
                  // Content Area
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      child: _buildCurrentView(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
  }
}