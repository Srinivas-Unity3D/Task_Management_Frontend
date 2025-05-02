import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_assignment.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../theme/colors.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/dashboard/side_panel.dart';
import './create_task_screen.dart';

class AssignTasksScreen extends StatefulWidget {
  const AssignTasksScreen({Key? key}) : super(key: key);

  @override
  State<AssignTasksScreen> createState() => _AssignTasksScreenState();
}

class _AssignTasksScreenState extends State<AssignTasksScreen> {
  final _apiService = ApiService();
  final _socketService = SocketService.instance;
  final _notificationService = NotificationService();
  List<TaskAssignment> _assignments = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentRole;
  String? _currentUsername;
  bool get _isAdmin =>
      _currentRole?.toLowerCase() == 'admin' ||
      _currentRole?.toLowerCase() == 'super admin';
  bool _hasUnreadNotifications = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    print('🔔 AssignTasksScreen - initState');
    _initializeServices();
    _loadUserAndAssignments();
  }

  Future<void> _initializeServices() async {
    print('🔔 AssignTasksScreen - Initializing services');
    await _notificationService.initialize();

    // Remove any existing listeners before adding new ones
    _socketService.removeTaskNotificationListener(_handleNewNotification);
    _socketService.listenToTaskNotifications(_handleNewNotification);

    print('🔔 AssignTasksScreen - Services initialized');
  }

  @override
  void dispose() {
    print('🔔 AssignTasksScreen - dispose');
    _socketService.removeTaskNotificationListener(_handleNewNotification);
    super.dispose();
  }

  void _handleNewNotification(dynamic data) {
    print('🔔 AssignTasksScreen - Received notification: $data');
    if (mounted) {
      // Check if this is a task update notification
      if (data['type'] == 'task_created' || data['type'] == 'task_updated') {
        print(
            '🔄 AssignTasksScreen - Task update received, refreshing assignments...');
        // Add slight delay before refreshing to ensure server has processed the update
        Future.delayed(const Duration(milliseconds: 500), () {
          _fetchAssignments();
        });
      }

      // Update notification indicator
      setState(() {
        _hasUnreadNotifications = true;
      });
    }
  }

  Future<void> _loadUserAndAssignments() async {
    try {
      print('🔄 AssignTasksScreen - Loading user data and assignments...');
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id');
      _currentRole = prefs.getString('role');
      _currentUsername = prefs.getString('username');

      // Connect to socket service
      final username = _currentUsername;
      if (username != null && username.isNotEmpty) {
        print('🔄 AssignTasksScreen - Connecting socket for user: $username');
        _socketService.connect(username);

        // Remove any existing listeners before adding new ones
        _socketService.removeTaskNotificationListener(_handleNewNotification);

        // Setup socket listeners
        print('🔄 AssignTasksScreen - Setting up socket listeners');
        _socketService.listenToTaskNotifications(_handleNewNotification);
      }

      if (_currentUserId != null) {
        await _fetchAssignments();
      }
    } catch (e) {
      print('❌ AssignTasksScreen - Error loading user and assignments: $e');
    }
  }

  Future<void> _fetchAssignments() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      print('🔄 AssignTasksScreen - Fetching assignments...');

      // Add retry logic
      int retryCount = 0;
      const maxRetries = 3;
      List<TaskAssignment>? assignments;

      while (retryCount < maxRetries && assignments == null) {
        try {
          // Get all assignments
          assignments = await _apiService.getTaskAssignments(_currentUserId!);
          
          // Filter assignments to only show tasks assigned by the current user to others
          if (assignments != null && _currentUsername != null) {
            assignments = assignments
                .where((assignment) => 
                  assignment.assignerName == _currentUsername && 
                  assignment.assigneeName != _currentUsername
                )
                .toList();
            print('🔄 AssignTasksScreen - Filtered ${assignments.length} tasks assigned by $_currentUsername to others');
          }
        } catch (e) {
          print('❌ AssignTasksScreen - Attempt ${retryCount + 1} failed: $e');
          retryCount++;
          if (retryCount < maxRetries) {
            // Wait before retrying
            await Future.delayed(Duration(seconds: 1));
          }
        }
      }

      if (assignments != null) {
        if (mounted) {
          setState(() {
            _assignments = assignments!;
            _isLoading = false;
          });
          print('✅ AssignTasksScreen - Assignments updated successfully');
        }
      } else {
        throw Exception(
            'Failed to fetch assignments after $maxRetries attempts');
      }
    } catch (e) {
      print('❌ AssignTasksScreen - Error fetching assignments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error fetching assignments. Pull to refresh to try again.'),
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: _fetchAssignments,
            ),
          ),
        );
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.yellow;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      key: _scaffoldKey,
      drawer: SidePanel(
        onLogout: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/');
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
        currentRoute: '/assign-tasks',
      ),
      body: Column(
        children: [
          CommonAppBar(
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            hasUnreadNotifications: _hasUnreadNotifications,
            onNotificationCleared: () {
              setState(() {
                _hasUnreadNotifications = false;
              });
            },
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Assign Tasks',
                  style: TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateTaskScreen(),
                      ),
                    );
                    if (result == true) {
                      _fetchAssignments();
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor.withOpacity(0.1),
                        width: 1,
                      ),
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
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAssignments,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _assignments.length,
                      itemBuilder: (context, index) {
                        final assignment = _assignments[index];
                        return _buildTaskAssignmentItem(assignment);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskAssignmentItem(TaskAssignment assignment) {
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
                  assignment.assigneeName[0].toUpperCase(),
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
                      assignment.assigneeName,
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      assignment.assigneeRole,
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
                          taskId: assignment.taskId,
                          initialTitle: assignment.taskName,
                          initialDescription: assignment.description,
                          initialAssignee: assignment.assigneeName,
                          initialPriority: assignment.priority,
                          initialDueDate: assignment.dueDate,
                          initialStatus: assignment.currentTask,
                        ),
                      ),
                    );
                    if (result == true) {
                      await _fetchAssignments();
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
                  assignment.taskName,
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
              color: _getPriorityColor(assignment.priority).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              assignment.priority,
              style: TextStyle(
                color: _getPriorityColor(assignment.priority),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
