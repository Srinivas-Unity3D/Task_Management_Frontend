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

  void _handleNewNotification(dynamic taskData) {
    if (!mounted) return;

    print('🔔 [MyTasks] Received task notification: $taskData');

    // Check if this notification is relevant for the current user
    if (_currentUsername == null) return;

    final bool isAssignee = taskData['assigned_to'] == _currentUsername;
    final bool isAssigner = taskData['assigned_by'] == _currentUsername;
    final bool isUpdater = taskData['updated_by'] == _currentUsername;

    print('🔍 [MyTasks] Notification relevance check:');
    print('Current user: $_currentUsername');
    print('Is assignee: $isAssignee');
    print('Is assigner: $isAssigner');
    print('Is updater: $isUpdater');

    // If the current user is involved in the task
    if (isAssignee || isAssigner) {
      // If the user is not the one who made the update
      if (!isUpdater) {
        final String title = taskData['type'] == 'task_created' 
            ? 'New Task Assigned'
            : 'Task Updated';
        
        final String message = taskData['type'] == 'task_created'
            ? 'A new task has been assigned to you'
            : 'Task "${taskData['title']}" has been updated';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: const Color(0xFF7DF9FF),
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
      }

      // Clear API cache to force fresh data
      _apiService.clearCache();

      // Add a slight delay before refreshing to ensure server has processed the update
      Future.delayed(const Duration(milliseconds: 500), () {
        print('🔄 [MyTasks] Reloading tasks after notification');
        _loadTasks();
      });
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
      if (!mounted) return;
      
      setState(() => _isLoading = true);

      // Only proceed if we have the current username
      if (_currentUsername == null) {
        print('❌ MyTasksScreen - Error: Current username is null');
        return;
      }

      print('🔄 MyTasksScreen - Loading tasks for user: $_currentUsername');
      
      // Force a fresh fetch by clearing cache first
      _apiService.clearCache();
      
      final response = await _apiService.getTasks(
        username: _currentUsername!,
        role: _currentRole ?? '',
      );

      if (!mounted) return;

      if (response['success']) {
        final tasksJson = response['data'] as List;
        final allTasks = tasksJson.map((task) => Task.fromJson(task)).toList();
        
        // Filter tasks where user is only the assignee
        final userTasks = allTasks.where((task) => 
          task.assignedTo == _currentUsername
        ).toList();
        
        print('📊 [MyTasks] Task breakdown:');
        print('Total tasks: ${allTasks.length}');
        print('Tasks assigned to $_currentUsername: ${allTasks.where((t) => t.assignedTo == _currentUsername).length}');
        print('Tasks assigned by $_currentUsername: ${allTasks.where((t) => t.assignedBy == _currentUsername).length}');
        print('Total relevant tasks: ${userTasks.length}');
        
        setState(() {
          _tasks = userTasks;
          _filteredTasks = userTasks;
          _isLoading = false;
        });
        print('✅ MyTasksScreen - Loaded ${_tasks.length} tasks for $_currentUsername');
      } else {
        throw Exception(response['message'] ?? 'Failed to load tasks');
      }
    } catch (e) {
      print('❌ MyTasksScreen - Error loading tasks: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tasks: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
      case TaskPriority.urgent:
        return Colors.red;
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
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
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
                          initialPriority: task.priority.toString().split('.').last,
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
          Row(
            children: [
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.borderColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  task.status.toString().split('.').last,
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.borderColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  'May ${task.deadline.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: SidePanel(
        onLogout: () {},
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
