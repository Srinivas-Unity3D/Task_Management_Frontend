import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_assignment.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/notification_firebase_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../theme/colors.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/dashboard/side_panel.dart';
import '../widgets/filter_panel.dart';
import './create_task_screen.dart';
import './notifications_screen.dart';

class AssignTasksScreen extends StatefulWidget {
  const AssignTasksScreen({Key? key}) : super(key: key);

  @override
  State<AssignTasksScreen> createState() => _AssignTasksScreenState();
}

class _AssignTasksScreenState extends State<AssignTasksScreen> {
  final _apiService = ApiService();
  final _socketService = SocketService.instance;
  final _notificationService = NotificationFirebaseService();
  List<TaskAssignment> _assignments = [];
  List<TaskAssignment> _filteredAssignments = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentRole;
  String? _currentUsername;
  bool get _isAdmin =>
      _currentRole?.toLowerCase() == 'admin' ||
          _currentRole?.toLowerCase() == 'super admin';
  bool _hasUnreadNotifications = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  OverlayEntry? _filterOverlay;

  @override
  void initState() {
    super.initState();
    print('🔔 AssignTasksScreen - initState');
    _initializeServices();
    _loadUserAndAssignments();
    _checkUnreadNotifications();
  }

  Future<void> _initializeServices() async {
    print('🔔 AssignTasksScreen - Initializing services');
    await _notificationService.initialize();
    _socketService.removeTaskNotificationListener(_handleNewNotification);
    _socketService.listenToTaskNotifications(_handleNewNotification);
    print('🔔 AssignTasksScreen - Services initialized');
  }

  @override
  void dispose() {
    print('🔔 AssignTasksScreen - dispose');
    _socketService.removeTaskNotificationListener(_handleNewNotification);
    _removeFilterPanel();
    super.dispose();
  }

  void _handleNewNotification(dynamic data) {
    print('🔔 AssignTasksScreen - Received notification: $data');
    if (mounted) {
      if (data['type'] == 'task_created' || data['type'] == 'task_updated') {
        print('🔄 AssignTasksScreen - Task update received, refreshing assignments...');
        Future.delayed(const Duration(milliseconds: 500), () {
          _fetchAssignments();
        });
      } else if (data['type'] == 'task_assigned') {
        print('🔄 AssignTasksScreen - Task assignment received, refreshing assignments...');
        Future.delayed(const Duration(milliseconds: 500), () {
          _fetchAssignments();
        });
      }
      setState(() {
        _hasUnreadNotifications = true;
      });
    }
  }

  Future<void> _loadUserAndAssignments() async {
    print('🔄 AssignTasksScreen - Loading user data and assignments...');
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _currentRole = prefs.getString('role');
    _currentUsername = prefs.getString('username');

    if (_currentUserId != null && _currentUsername != null) {
      print('✅ AssignTasksScreen - User data loaded: ID=$_currentUserId, Username=$_currentUsername, Role=$_currentRole');
      // Connect socket
      print('🔄 AssignTasksScreen - Connecting socket for user: $_currentUsername');
      _socketService.connect(_currentUsername!);
      _socketService.removeTaskNotificationListener(_handleNewNotification);
      print('🔄 AssignTasksScreen - Setting up socket listeners');
      _socketService.listenToTaskNotifications(_handleNewNotification);
      // Fetch assignments
      await _fetchAssignments();
    } else {
      print('⚠️ AssignTasksScreen - User data missing, not fetching assignments');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final notifications = await _notificationService.getNotifications();
      final hasUnread = notifications.any((n) => !n.isCompleted);
      _notificationService.setUnreadState(hasUnread);
      if (mounted) {
        setState(() {
          _hasUnreadNotifications = hasUnread;
        });
      }
    } catch (e) {
      print('❌ [AssignTasks] Error checking unread notifications: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUnreadNotifications();
  }

  void _showFilterPanel(BuildContext context, Offset buttonPosition) {
    _removeFilterPanel();
    final buttonSize = 40.0;
    final headerHeight = 80.0;
    final topPadding = 16.0;
    final extraTopOffset = 8.0;
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
            top: headerHeight + topPadding + buttonSize + extraTopOffset,
            right: 70,
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
      _filteredAssignments = _assignments
          .where((assignment) =>
      assignment.priority.toLowerCase() == priority.toLowerCase())
          .toList();
    });
    _removeFilterPanel();
  }

  void _sortByAssignee(String order) {
    setState(() {
      _filteredAssignments = List.from(_assignments)
        ..sort((a, b) => order == 'asc'
            ? a.assigneeName.compareTo(b.assigneeName)
            : b.assigneeName.compareTo(a.assigneeName));
    });
    _removeFilterPanel();
  }

  void _filterByRecent() {
    setState(() {
      _filteredAssignments = List.from(_assignments)
        ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    });
    _removeFilterPanel();
  }

  void _filterByRole(String role) {
    _removeFilterPanel();
  }

  Future<void> _fetchAssignments() async {
    if (!mounted) return;
    try {
      setState(() {
        _isLoading = true;
      });
      print('🔄 AssignTasksScreen - Fetching assignments...');
      
      // Check if we have the required user data
      if (_currentUserId == null) {
        print('❌ AssignTasksScreen - Current user ID is null');
        throw Exception('User not logged in');
      }

      int retryCount = 0;
      const maxRetries = 3;
      List<TaskAssignment>? assignments;
      
      while (retryCount < maxRetries && assignments == null) {
        try {
          assignments = await _apiService.getTaskAssignments(_currentUserId!);
          print('DEBUG: Raw assignments from API: ' + assignments.toString());
          print('DEBUG: Current username: ' + (_currentUsername ?? 'null'));
          if (assignments != null && _currentUsername != null) {
            if (!_isAdmin) {
              assignments = assignments
                  .where((assignment) =>
                      assignment.assignerName == _currentUsername)
                  .toList();
              print('DEBUG: Filtered assignments: ' + assignments.toString());
              print('🔄 AssignTasksScreen - Filtered ${assignments.length} tasks assigned by $_currentUsername');
            } else {
              print('🔄 AssignTasksScreen - Showing all ${assignments.length} tasks for admin user');
            }
          }
        } catch (e) {
          print('❌ AssignTasksScreen - Attempt ${retryCount + 1} failed: $e');
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: 1));
          }
        }
      }

      if (assignments != null) {
        if (mounted) {
          setState(() {
            _assignments = assignments!;
            _filteredAssignments = assignments!;
            _isLoading = false;
          });
          print('✅ AssignTasksScreen - Assignments updated successfully');
        }
      } else {
        throw Exception('Failed to fetch assignments after $maxRetries attempts');
      }
    } catch (e) {
      print('❌ AssignTasksScreen - Error fetching assignments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching assignments: ${e.toString()}'),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.pending;
      case 'in_progress':
      case 'inprogress':
        return AppColors.inProgress;
      case 'completed':
        return AppColors.completed;
      default:
        return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      key: _scaffoldKey,
      drawer: SidePanel(
        // onLogout: () async {
        //   final prefs = await SharedPreferences.getInstance();
        //   await prefs.clear();
        //   if (mounted) {
        //     Navigator.of(context).pushNamedAndRemoveUntil(
        //       '/',
        //       (route) => false,
        //     );
        //   }
        // },
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
            hasUnreadNotifications: _notificationService.getUnreadState(),
            onNotificationCleared: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
              
              if (result == true && mounted) {
                _notificationService.setUnreadState(false);
                setState(() {
                  _hasUnreadNotifications = false;
                });
              }
            },
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Assigned Tasks',
                  style: TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Container(
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
                      child: IconButton(
                        icon: const Icon(Icons.filter_list, color: AppColors.accentCyan),
                        onPressed: () {
                          final RenderBox button = context.findRenderObject() as RenderBox;
                          final Offset buttonPosition = button.localToGlobal(Offset.zero);
                          _showFilterPanel(context, buttonPosition);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
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
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAssignments,
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _filteredAssignments.length,
                itemBuilder: (context, index) {
                  final assignment = _filteredAssignments[index];
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
    String _formatDate(DateTime date) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

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
                          initialAssigner: assignment.assignerName, // Added
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
          Row(
            children: [
              // Priority badge
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
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(assignment.currentTask).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  assignment.currentTask,
                  style: TextStyle(
                    color: _getStatusColor(assignment.currentTask),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Due date
              Icon(Icons.calendar_today, size: 12, color: AppColors.textGrey),
              const SizedBox(width: 2),
              Text(
                _formatDate(assignment.dueDate),
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}