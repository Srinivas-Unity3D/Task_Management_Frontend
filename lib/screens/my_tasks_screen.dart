import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/notification_state_service.dart';
import '../services/socket_service.dart';
import '../services/audio_service.dart';
import '../theme/colors.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/dashboard/side_panel.dart';
import '../widgets/filter_panel.dart';
import './create_task_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({Key? key}) : super(key: key);

  @override
  _MyTasksScreenState createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final ApiService _apiService = ApiService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _notificationState = NotificationStateService();
  final _socketService = SocketService.instance;
  final _audioService = AudioService();
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;
  String? _currentUserId;
  String? _currentRole;
  String? _currentUsername;
  OverlayEntry? _filterOverlay;

  @override
  void initState() {
    super.initState();
    print('🔄 MyTasksScreen - Initializing...');
    _loadUserAndTasks();
    _notificationState.addListener(_onNotificationStateChanged);
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔔 MyTasksScreen - Setting up socket listeners');
    // Remove any existing listeners before adding new ones
    _socketService.removeTaskNotificationListener(_handleNewNotification);
    _socketService.listenToTaskNotifications(_handleNewNotification);
  }

  void _handleNewNotification(dynamic data) {
    print('🔔 MyTasksScreen - Received notification: $data');
    if (mounted) {
      // Check if this is a task update notification
      if (data['type'] == 'task_created' || data['type'] == 'task_updated') {
        print('🔄 MyTasksScreen - Task update received, refreshing tasks...');
        
        // Play notification sound and vibrate
        _audioService.playNotificationSound();
        HapticFeedback.mediumImpact();
        
        // Show snackbar if screen is visible and notification hasn't been shown yet
        if (ModalRoute.of(context)!.isCurrent && !_notificationState.notificationShown) {
          final taskData = data['task'] ?? data;
          final bool isUpdate = taskData['updated_by'] != null;
          final String title = isUpdate ? 'Task Updated' : 'New Task Assigned';
          final String message = isUpdate 
              ? '${taskData['title']} updated by ${taskData['updated_by']}'
              : taskData['title'] ?? 'No title';

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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateTaskScreen(
                        isEditMode: true,
                        taskId: taskData['task_id'],
                        initialTitle: taskData['title'],
                        initialDescription: taskData['description'],
                        initialAssignee: taskData['assigned_to'],
                        initialPriority: taskData['priority'],
                        initialDueDate: DateTime.parse(taskData['deadline']),
                        initialStatus: taskData['status'],
                      ),
                    ),
                  ).then((_) => _loadTasks());
                },
              ),
            ),
          );
          // Mark that notification was shown
          _notificationState.markNotificationShown();
        }

        // Add slight delay before refreshing to ensure server has processed the update
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadTasks();
        });
      }

      // Update notification state
      _notificationState.setUnreadNotifications(true);
    }
  }

  @override
  void dispose() {
    _socketService.removeTaskNotificationListener(_handleNewNotification);
    _removeFilterPanel();
    _notificationState.removeListener(_onNotificationStateChanged);
    super.dispose();
  }

  void _showFilterPanel(BuildContext context, Offset buttonPosition) {
    _removeFilterPanel();

    final buttonSize = 40.0; // Height of the filter button
    final headerHeight = 80.0; // Approximate height of the header section
    final topPadding = 16.0; // Padding above the filter button
    final extraTopOffset = 20.0; // Extra space below the button

    _filterOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _removeFilterPanel,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            top: headerHeight +
                topPadding +
                buttonSize +
                extraTopOffset, // Added extra space below
            right: 75, // Moved left by reducing right padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.rotate(
                  angle: 0.785,
                  child: Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                FilterPanel(
                  onPrioritySelected: _filterByPriority,
                  onAssigneeSort: _sortByAssignee,
                  onRecentTasksSelected: _filterByRecent,
                  onRoleSelected: _filterByRole,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_filterOverlay!);
  }

  void _removeFilterPanel() {
    _filterOverlay?.remove();
    _filterOverlay = null;
  }

  void _filterByPriority(String priority) {
    setState(() {
      _filteredTasks = _tasks
          .where((task) =>
              task.priority.toString().split('.').last.toLowerCase() ==
              priority.toLowerCase())
          .toList();
    });
    _removeFilterPanel();
  }

  void _sortByAssignee(String order) {
    setState(() {
      _filteredTasks = List.from(_tasks)
        ..sort((a, b) => order == 'asc'
            ? a.assignedBy.compareTo(b.assignedBy)
            : b.assignedBy.compareTo(a.assignedBy));
    });
    _removeFilterPanel();
  }

  void _filterByRecent() {
    setState(() {
      _filteredTasks = List.from(_tasks)
        ..sort((a, b) => b.deadline.compareTo(a.deadline));
    });
    _removeFilterPanel();
  }

  void _filterByRole(String role) {
    // Implement role filtering if needed
    _removeFilterPanel();
  }

  void _onNotificationStateChanged() {
    print('🔔 MyTasksScreen - Notification state changed: ${_notificationState.hasUnreadNotifications}');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUserAndTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id');
      _currentRole = prefs.getString('role');
      _currentUsername = prefs.getString('username');
      await _loadTasks();
    } catch (e) {
      print('Error loading user and tasks: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      setState(() => _isLoading = true);

      // Only proceed if we have the current username
      if (_currentUsername == null) {
        print('Error: Current username is null');
        return;
      }

      final response = await _apiService.getTasks(
          username: _currentUsername!, role: _currentRole ?? '');
      if (response['success']) {
        final tasksJson = response['data'] as List;
        setState(() {
          _tasks = tasksJson
              .map((task) => Task.fromJson(task))
              .where((task) => task.assignedTo == _currentUsername) // Only show tasks assigned to the admin
              .toList();
          _filteredTasks = _tasks;
        });
        print('📋 MyTasksScreen - Loaded ${_tasks.length} tasks assigned to $_currentUsername');
      }
    } catch (e) {
      print('❌ MyTasksScreen - Error loading tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tasks: ${e.toString()}'),
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

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.yellow;
      case TaskPriority.high:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTaskCard(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.inputBackground,
                child: Text(
                  task.assignedBy[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 16,
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
                      task.assignedBy,
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      task.assignedByRole,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentCyan,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateTaskScreen(
                          isEditMode: true,
                          taskId: task.taskId,
                          initialTitle: task.title,
                          initialDescription: task.description,
                          initialAssignee: task.assignedTo,
                          initialPriority:
                              task.priority.toString().split('.').last,
                          initialDueDate: task.deadline,
                          initialStatus: task.status.toString().split('.').last,
                        ),
                      ),
                    );
                    if (result == true) {
                      await _loadTasks();
                    }
                  },
                  icon: const Icon(
                    Icons.edit,
                    color: AppColors.background,
                    size: 16,
                  ),
                  label: const Text(
                    'View/Edit',
                    style: TextStyle(
                      color: AppColors.background,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Task: ',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getPriorityColor(task.priority).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              task.priority.toString().split('.').last,
              style: TextStyle(
                color: _getPriorityColor(task.priority),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: SidePanel(
        onLogout: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          }
        },
        onClose: () => Navigator.pop(context),
        user: User(
          userId: _currentUserId ?? '',
          username: _currentUsername ?? '',
          email: '${_currentUsername ?? 'user'}@example.com',
          phone: '',
          role: _currentRole ?? '',
        ),
        currentRoute: '/my-tasks',
      ),
      body: Column(
        children: [
          CommonAppBar(
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            hasUnreadNotifications: _notificationState.hasUnreadNotifications,
            onNotificationCleared: _notificationState.clearNotifications,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                const Text(
                  'My Tasks',
                  style: TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list,
                        color: AppColors.accentCyan),
                    onPressed: () {
                      final RenderBox button =
                          context.findRenderObject() as RenderBox;
                      final Offset buttonPosition =
                          button.localToGlobal(Offset.zero);
                      _showFilterPanel(context, buttonPosition);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon:
                        const Icon(Icons.download, color: AppColors.accentCyan),
                    onPressed: () {
                      // TODO: Implement download functionality
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.accentCyan),
                  )
                : _filteredTasks.isEmpty
                    ? const Center(
                        child: Text(
                          'No tasks available',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTasks,
                        color: AppColors.accentCyan,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: _filteredTasks.length,
                          itemBuilder: (context, index) =>
                              _buildTaskCard(_filteredTasks[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
