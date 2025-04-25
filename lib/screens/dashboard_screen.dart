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
import '../screens/create_task_screen.dart';
import '../screens/assign_tasks_screen.dart';
import '../services/socket_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _apiService = ApiService();
  final _socketService = SocketService();
  late User _user;
  TaskStats? _taskStats;
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;
  ViewState _currentView = ViewState.dashboard;
  List<Task> _userTasks = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndSetupSocket();
  }

  @override
  void dispose() {
    // Remove socket listeners when disposing
    _socketService.removeTaskNotificationListener(_handleTaskNotification);
    _socketService.removeDashboardUpdateListener(_handleDashboardUpdate);
    super.dispose();
  }

  Future<void> _loadUserAndSetupSocket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      if (username != null) {
        // Connect socket with username
        _socketService.connect(username);
        // Setup socket listeners
        _setupSocketListeners();
      }
      _loadTasks();
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _setupSocketListeners() {
    // Listen for task notifications
    _socketService.listenToTaskNotifications(_handleTaskNotification);
    // Listen for dashboard updates
    _socketService.listenToDashboardUpdates(_handleDashboardUpdate);
  }

  void _handleTaskNotification(dynamic data) {
    if (mounted) {
      // Check if the current user is the creator/updater
      final bool isCreator = data['task']?['assigned_by'] == _user.username;
      final bool isUpdater = data['task']?['updated_by'] == _user.username;
      
      // Only show notification if user is not the creator/updater
      if (!isCreator && !isUpdater) {
        setState(() {
          _hasUnreadNotifications = true;
        });
        
        // Show notification for new tasks or updates
        if (data['type'] == 'task_created' || data['type'] == 'task_updated') {
          _showTaskNotification(data['task']);
        }
      }
      
      // Always refresh tasks list to keep it up to date
      _loadTasks();
    }
  }

  void _handleDashboardUpdate(dynamic data) {
    if (mounted) {
      // Only show notification if user is not the creator/updater
      final bool isCreator = data['assigned_by'] == _user.username;
      final bool isUpdater = data['updated_by'] == _user.username;
      
      if (!isCreator && !isUpdater) {
        setState(() {
          _hasUnreadNotifications = true;
        });
      }
      // Always refresh the task list
      _loadTasks();
    }
  }

  void _clearNotifications() {
    setState(() {
      _hasUnreadNotifications = false;
    });
  }

  void _showTaskNotification(Map<String, dynamic> task) {
    final bool isUpdate = task['updated_by'] != null;
    final String title = isUpdate ? 'Task Updated' : 'New Task Assigned';
    final String message = isUpdate 
        ? '${task['title']} updated by ${task['updated_by']}'
        : task['title'] ?? 'No title';

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Color(0xFF7DF9FF),
          onPressed: () {
            // Navigate to task details
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateTaskScreen(
                  isEditMode: true,
                  taskId: task['task_id'],
                  initialTitle: task['title'],
                  initialDescription: task['description'],
                  initialAssignee: task['assigned_to'],
                  initialPriority: task['priority'],
                  initialDueDate: DateTime.parse(task['deadline']),
                  initialStatus: task['status'],
                ),
              ),
            ).then((_) => _loadTasks()); // Refresh after returning from edit screen
          },
        ),
      ),
    );

    // Set notification dot if the notification is not being actively viewed
    if (!ModalRoute.of(context)!.isCurrent) {
      setState(() {
        _hasUnreadNotifications = true;
      });
    }
  }

  Future<void> _loadTasks() async {
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
    // Disconnect socket
    _socketService.disconnect();
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
    return GestureDetector(
      onTap: _clearNotifications,
      child: Container(
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
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
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
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
          ),
        ),
      ],
    );
  }

  Widget _buildMyTasksView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _userTasks.length,
            itemBuilder: (context, index) {
              final task = _userTasks[index];
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
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Task History',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.completed,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Completed',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Snoozed',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildNotificationIcon(
                hasUnreadNotifications: _hasUnreadNotifications,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Completed Tasks',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _taskStats?.completedTasks.toString() ?? '0',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Snoozed Tasks',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _taskStats?.snoozedTasks.toString() ?? '0',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ..._userTasks
                  .where((task) => 
                      task.status == TaskStatus.completed || 
                      task.status == TaskStatus.snoozed)
                  .map((task) => Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: task.status == TaskStatus.completed
                                    ? AppColors.completed
                                    : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                      : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMemberItem({
    required String name,
    required String role,
    required String currentTask,
    required VoidCallback onAssign,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Member Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentTask,
                  style: const TextStyle(
                    color: Color(0xFF7DF9FF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Assign Task Button
          TextButton.icon(
            onPressed: onAssign,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF7DF9FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Text(
              'Assign Task',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            label: const Icon(
              Icons.edit,
              color: Color(0xFF0F172A),
              size: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to handle task assignment
  void _showAssignTaskDialog(String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Assign Task to $memberName',
          style: const TextStyle(
            color: AppColors.accentCyan,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add task assignment form here
            // You can add fields for task title, description, deadline, etc.
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Handle task assignment
              Navigator.pop(context);
            },
            child: const Text(
              'Assign',
              style: TextStyle(color: AppColors.accentCyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignTasksView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
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
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateTaskScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          color: AppColors.accentCyan,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildNotificationIcon(
                    hasUnreadNotifications: _hasUnreadNotifications,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTeamMemberItem(
                    name: 'Ayan',
                    role: 'Developer',
                    currentTask: 'Website Redesign',
                    onAssign: () {
                      _showAssignTaskDialog('Ayan');
                    },
                  ),
                  _buildTeamMemberItem(
                    name: 'Azim',
                    role: 'Admin',
                    currentTask: 'API Integration',
                    onAssign: () {
                      _showAssignTaskDialog('Azim');
                    },
                  ),
                  _buildTeamMemberItem(
                    name: 'Durga',
                    role: 'Product Manager',
                    currentTask: 'User Research',
                    onAssign: () {
                      _showAssignTaskDialog('Durga');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
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
        return const AssignTasksScreen();
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
                      onDashboardPressed: () => _switchView(ViewState.dashboard),
                      currentView: _currentView,
                    ),
                  ),
                  // Content Area
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadTasks,
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