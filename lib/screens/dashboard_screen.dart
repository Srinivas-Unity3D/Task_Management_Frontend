import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_firebase_service.dart';
import '../widgets/dashboard/profile_section.dart';
import '../widgets/dashboard/navigation_menu.dart';
import '../widgets/dashboard/stats_card.dart';
import '../models/user.dart';
import '../models/task.dart';
import '../models/task_stats.dart';
import '../models/view_state.dart';
import '../theme/colors.dart';
import 'sign_in_screen.dart';
import '../widgets/dashboard/side_panel.dart';
import '../widgets/custom_text_field.dart';
import '../services/api_service.dart';
import '../screens/create_task_screen.dart';
import '../screens/assign_tasks_screen.dart';
import '../screens/my_tasks_screen.dart';
import '../services/socket_service.dart';
import '../widgets/common_notification_icon.dart';
import '../services/audio_service.dart';
import '../widgets/common_app_bar.dart';
import '../services/notification_service.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _apiService = ApiService();
  final _socketService = SocketService.instance;
  final _audioService = AudioService();
  final _notificationService = NotificationService();
  User? _user;
  TaskStats? _taskStats;
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;
  ViewState _currentView = ViewState.dashboard;
  List<Task> _userTasks = [];

  NotificationFirebaseService notificationService = NotificationFirebaseService();

  @override
  void initState() {
    super.initState();
    print('🔄 Dashboard - Initializing...');
    _initializeServices();
    
    // Setup socket listeners immediately
    _setupSocketListeners();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationService();
    });
  }

  void _setupNotificationService() {
    final notificationService = Get.put(NotificationFirebaseService());
    notificationService.initialize();
  }

  void _setupSocketListeners() {
    print('🔄 [Dashboard] Setting up socket listeners');
    // Remove any existing listeners first
    _socketService.removeAllListeners();
    
    // Add new listeners
    print('🔄 [Dashboard] Adding task notification listener');
    _socketService.listenToTaskNotifications((data) {
      print('📬 [Dashboard] Raw notification received: $data');
      if (mounted) {
        _handleTaskNotification(data);
      }
    });
    
    print('🔄 [Dashboard] Adding dashboard update listener');
    _socketService.listenToDashboardUpdates((data) {
      print('📊 [Dashboard] Raw dashboard update received: $data');
      if (mounted) {
        _handleDashboardUpdate(data);
      }
    });
    
    print('✅ [Dashboard] Socket listeners setup complete');
  }

  @override
  void dispose() {
    print('🔄 Dashboard - Disposing...');
    // Remove socket listeners
    _socketService.removeAllListeners();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      print('🔄 Dashboard - Initializing services...');
      await _audioService.initialize();
      print('🔄 Dashboard - Audio service initialized');

      // Load initial data
      await _loadUserAndSetupSocket();
      print('🔄 Dashboard - Initial data loaded');

      // Initial tasks load
      await _loadTasks();
      print('🔄 Dashboard - Initial tasks loaded');
    } catch (e) {
      print('❌ Dashboard - Error initializing services: $e');
    }
  }

  Future<void> _loadUserAndSetupSocket() async {
    try {
      print('🔄 Dashboard - Loading user data...');
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final userId = prefs.getString('user_id') ?? '';

      if (username != null) {
        // Set up user data
        _user = User(
          userId: userId,
          username: username,
          email: '$username@example.com',
          phone: '+1234567890',
          role: prefs.getString('role') ?? '',
          fcmToken: null,
        );

        print('🔄 Dashboard - Connecting socket for user: $username');
        // Connect socket with username
        _socketService.connect(username);

        // Setup socket listeners
        print('🔄 Dashboard - Setting up socket listeners');
        _setupSocketListeners();
      }
    } catch (e) {
      print('❌ Dashboard - Error loading user data: $e');
    }
  }

  void _playNotificationSound() async {
    try {
      print('🔔 Dashboard - Playing notification sound...');
      await _audioService.playNotificationSound();
      await HapticFeedback.mediumImpact();
      print('🔔 Dashboard - Notification sound and haptic feedback completed');
    } catch (e) {
      print('🔔 Dashboard - Error playing notification: $e');
    }
  }

  void _handleTaskNotification(dynamic data) {
    print('📬 [Dashboard] Processing task notification: $data');
    if (!mounted) {
      print('❌ [Dashboard] Widget not mounted, skipping notification');
      return;
    }

    try {
      // Only play sound and vibrate if the notification is from another user
      if (data['sender'] != _user?.username) {
        print('🔔 [Dashboard] Playing notification sound...');
        _audioService.playNotificationSound();
        print('📳 [Dashboard] Triggering vibration...');
        _notificationService.vibrate();
        
        // Show notification in notification bar
        print('🔔 [Dashboard] Showing system notification...');
        _notificationService.showNotification(
          title: 'New Task Update',
          body: data['message'] ?? 'You have a new task update',
          payload: json.encode(data),
        );
      } else {
        print('👤 [Dashboard] Skipping notification - from current user');
      }

      // Update task list and show notification badge
      print('🔄 [Dashboard] Updating task list and badge...');
      setState(() {
        _hasUnreadNotifications = true;
      });
      _loadTasks();
      print('✅ [Dashboard] Notification handling complete');
    } catch (e) {
      print('❌ [Dashboard] Error handling notification: $e');
    }
  }

  void _handleDashboardUpdate(dynamic data) {
    print('📊 [Dashboard] Processing dashboard update: $data');
    if (!mounted) {
      print('❌ [Dashboard] Widget not mounted, skipping update');
      return;
    }

    try {
      print('🔄 [Dashboard] Refreshing task list...');
      _loadTasks();
      print('✅ [Dashboard] Dashboard update complete');
    } catch (e) {
      print('❌ [Dashboard] Error handling dashboard update: $e');
    }
  }

  void _clearNotifications() {
    if (mounted) {
      setState(() {
        _hasUnreadNotifications = false;
      });
    }
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
    try {
      setState(() => _isLoading = true);
      final response = await _apiService.getTasks(username: _user!.username, role: _user!.role);
      if (mounted) {
        setState(() {
          if (response['success']) {
            final tasksJson = response['data'] as List;
            _userTasks = tasksJson.map((task) => Task.fromJson(task)).toList();
            _taskStats = TaskStats.fromTasks(_userTasks);
          } else {
            _userTasks = [];
            _taskStats = TaskStats(
              activeTasks: 0,
              pendingTasks: 0,
              inProgressTasks: 0,
              completedTasks: 0,
              snoozedTasks: 0,
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Dashboard - Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userTasks = [];
          _taskStats = TaskStats(
            activeTasks: 0,
            pendingTasks: 0,
            inProgressTasks: 0,
            completedTasks: 0,
            snoozedTasks: 0,
          );
        });
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
          builder: (context) => SignInScreen(
            onLogin: () {
              // This callback won't be used in practice since we're logging out
              // but we need to provide it to satisfy the type system
            },
          ),
        ),
      );
    }
  }

  void _showSidePanel() {
    if (_user == null) return; // Don't show panel if user is not initialized

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
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
                  user: _user!,
                  currentRoute: '/',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _switchView(ViewState newView) {
    switch (newView) {
      case ViewState.myTasks:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyTasksScreen(),
          ),
        ).then((_) => _loadTasks()); // Refresh tasks after returning
        break;
      case ViewState.assignTasks:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AssignTasksScreen(),
          ),
        ).then((_) => _loadTasks()); // Refresh tasks after returning
        break;
      case ViewState.dashboard:
        // No navigation needed for dashboard
        break;
    }
    setState(() {
      _currentView = newView;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null || _isLoading) {
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
      body: Column(
        children: [
          CommonAppBar(
            onMenuPressed: _showSidePanel,
            hasUnreadNotifications: _hasUnreadNotifications,
            onNotificationCleared: _clearNotifications,
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: _buildDashboardView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                StatsCard(
                  title: 'Snoozed',
                  count: _taskStats?.snoozedTasks.toString() ?? '0',
                ),
                StatsCard(
                  title: 'Active Tasks',
                  count: _taskStats?.activeTasks.toString() ?? '0',
                ),
                StatsCard(
                  title: 'Pending Tasks',
                  count: _taskStats?.pendingTasks.toString() ?? '0',
                ),
                StatsCard(
                  title: 'Completed',
                  count: _taskStats?.completedTasks.toString() ?? '0',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // My Tasks Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.borderColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Tasks',
                          style: TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _switchView(ViewState.myTasks),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._userTasks
                      .where((task) => task.assignedTo == _user!.username)
                      .take(2)
                      .map((task) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderColor.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: const TextStyle(
                                            color: AppColors.accentCyan,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Due ${_formatDate(task.deadline)}',
                                        style: const TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    task.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                  if (_userTasks.where((task) => task.assignedTo == _user!.username).isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        'No tasks available',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Assigned Tasks Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.borderColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Assigned Tasks',
                          style: TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _switchView(ViewState.assignTasks),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        ..._buildAssignedTaskGroups(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildAssignedTaskGroups() {
    // Get tasks assigned by the current user
    final assignedTasks = _userTasks
        .where((task) => task.assignedBy == _user!.username)
        .take(2) // Take only 2 tasks for preview
        .toList();

    if (assignedTasks.isEmpty) {
      return [
        const Text(
          'No assigned tasks',
          style: TextStyle(
            color: AppColors.textGrey,
            fontSize: 14,
          ),
        ),
      ];
    }

    return assignedTasks.map((task) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.borderColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'Due ${_formatDate(task.deadline)}',
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Assigned to: ${task.assignedTo}',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
  }

  void _showAssignTaskDialog(String memberName) {
    final TextEditingController _titleController = TextEditingController();
    final TextEditingController _descriptionController = TextEditingController();

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
            CustomTextField(
              label: 'Task Title',
              hint: 'Enter task title',
              controller: _titleController,
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Description',
              hint: 'Enter task description',
              controller: _descriptionController,
              maxLines: 3,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _titleController.dispose();
              _descriptionController.dispose();
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Handle task assignment
              _titleController.dispose();
              _descriptionController.dispose();
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
}