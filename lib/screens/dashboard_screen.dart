import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/dashboard/side_panel.dart';
import '../widgets/custom_text_field.dart';
import '../services/api_service.dart';
import '../screens/create_task_screen.dart';
import '../screens/assign_tasks_screen.dart';
import '../services/socket_service.dart';
import '../widgets/common_notification_icon.dart';
import '../services/audio_service.dart';
import '../widgets/common_app_bar.dart';

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
  late User _user;
  TaskStats? _taskStats;
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;
  ViewState _currentView = ViewState.dashboard;
  List<Task> _userTasks = [];

  @override
  void initState() {
    super.initState();
    print('🔄 Dashboard - Initializing...');
    _initializeServices();
  }

  @override
  void dispose() {
    // Remove socket listeners when disposing
    _socketService.removeTaskNotificationListener(_handleTaskNotification);
    _socketService.removeDashboardUpdateListener(_handleDashboardUpdate);
    _audioService.dispose();
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
        
        // Remove any existing listeners before adding new ones
        _socketService.removeTaskNotificationListener(_handleTaskNotification);
        _socketService.removeDashboardUpdateListener(_handleDashboardUpdate);
        
        // Setup socket listeners
        print('🔄 Dashboard - Setting up socket listeners');
        _setupSocketListeners();
      }
    } catch (e) {
      print('❌ Dashboard - Error loading user data: $e');
    }
  }

  void _setupSocketListeners() {
    // Listen for task notifications
    _socketService.listenToTaskNotifications(_handleTaskNotification);
    // Listen for dashboard updates
    _socketService.listenToDashboardUpdates(_handleDashboardUpdate);
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
    if (mounted) {
      print('🔔 Dashboard - Received task notification: $data');
      
      // Check if the current user is the creator/updater
      final bool isCreator = data['task']?['assigned_by'] == _user.username;
      final bool isUpdater = data['task']?['updated_by'] == _user.username;
      
      // Only show notification if user is not the creator/updater
      if (!isCreator && !isUpdater) {
        setState(() {
          _hasUnreadNotifications = true;
        });
        
        // Play notification sound and vibrate
        _playNotificationSound();
        
        // Show notification for new tasks or updates
        if (data['type'] == 'task_created' || data['type'] == 'task_updated') {
          _showTaskNotification(data['task']);
        }
      }
      
      // Always refresh tasks list to keep it up to date
      print('🔄 Dashboard - Refreshing tasks after notification...');
      _loadTasks();
    }
  }

  void _handleDashboardUpdate(dynamic data) async {
    if (mounted) {
      print('📨 Dashboard - Received update: $data');
      
      // Check if the current user is the creator/updater
      final bool isCreator = data['assigned_by'] == _user.username;
      final bool isUpdater = data['updated_by'] == _user.username;
      
      // Play notification sound if user is not the creator/updater
      if (!isCreator && !isUpdater) {
        setState(() {
          _hasUnreadNotifications = true;
        });
        _playNotificationSound();
      }

      // Always refresh tasks list regardless of who created/updated
      print('🔄 Dashboard - Refreshing tasks after update...');
      await _loadTasks();
      
      // Show a snackbar with the update message
      if (mounted) {
        final String actionType = data['type'] == 'task_created' ? 'created' : 'updated';
        final String message = isCreator || isUpdater 
          ? 'Task $actionType successfully!'
          : 'A task has been $actionType';
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
    setState(() => _isLoading = true);

    try {
      // Get the stored user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';
      final userId = prefs.getString('user_id') ?? '';
      final role = prefs.getString('role') ?? '';

      // Load user data
      _user = User(
        userId: userId,
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
        setState(() {
          _userTasks = tasksJson.map((task) => Task.fromJson(task)).toList();
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
                  user: _user,
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
    setState(() {
      _currentView = newView;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: SafeArea(
              top: false,
              child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accentCyan),
                  )
                : _buildDashboardView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          backgroundColor: AppColors.background,
          pinned: true,
          automaticallyImplyLeading: false,
          expandedHeight: 100,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            title: const Text(
              'Dashboard',
              style: TextStyle(
                color: AppColors.accentCyan,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  StatsCard(
                    title: 'Snoozed',
                    count: _taskStats?.snoozedTasks.toString() ?? '0',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // My Tasks Section
                  Expanded(
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
                              .where((task) => task.assignedTo == _user.username)
                              .take(2)
                              .map((task) => Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                                      ],
                                    ),
                                  ))
                              .toList(),
                          if (_userTasks.where((task) => task.assignedTo == _user.username).isEmpty)
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
                  const SizedBox(width: 16),
                  // Assigned Tasks Section
                  Expanded(
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
                                Expanded(
                                  child: Text(
                                    'Assigned Tasks',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAssignedTaskGroups() {
    // Group tasks by assignee
    final assignedTasks = _userTasks.where((task) => task.assignedBy == _user.username);
    final assigneeGroups = <String, Map<String, dynamic>>{};

    for (var task in assignedTasks) {
      if (!assigneeGroups.containsKey(task.assignedTo)) {
        assigneeGroups[task.assignedTo] = {
          'activeTasks': 0,
          'completedTasks': 0,
        };
      }

      if (task.status == TaskStatus.completed) {
        assigneeGroups[task.assignedTo]!['completedTasks']++;
      } else {
        assigneeGroups[task.assignedTo]!['activeTasks']++;
      }
    }

    if (assigneeGroups.isEmpty) {
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

    return assigneeGroups.entries.take(2).map((entry) {
      return Column(
        children: [
          _buildAssignedTaskMember(
            name: entry.key,
            role: 'Team Member',
            activeTasks: entry.value['activeTasks'].toString(),
            completedTasks: entry.value['completedTasks'].toString(),
          ),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  Widget _buildAssignedTaskMember({
    required String name,
    required String role,
    required String activeTasks,
    required String completedTasks,
  }) {
    return Container(
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
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.cardBackground,
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      role,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeTasks,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'Active',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            completedTasks,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'Completed',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tasks',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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