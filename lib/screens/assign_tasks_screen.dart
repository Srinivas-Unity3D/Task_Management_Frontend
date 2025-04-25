import 'package:flutter/material.dart';
import '../models/task_assignment.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../theme/colors.dart';
import '../widgets/common_notification_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './create_task_screen.dart';
import './notification_screen.dart';

class AssignTasksScreen extends StatefulWidget {
  const AssignTasksScreen({Key? key}) : super(key: key);

  @override
  State<AssignTasksScreen> createState() => _AssignTasksScreenState();
}

class _AssignTasksScreenState extends State<AssignTasksScreen> {
  final _apiService = ApiService();
  final _socketService = SocketService();
  final _notificationService = NotificationService();
  List<TaskAssignment> _assignments = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentRole;
  bool get _isAdmin => _currentRole?.toLowerCase() == 'admin' || _currentRole?.toLowerCase() == 'super admin';
  bool _hasUnreadNotifications = false;

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
      print('🔔 AssignTasksScreen - Setting hasUnreadNotifications to true');
      setState(() {
        _hasUnreadNotifications = true;
      });
    }
  }

  Future<void> _loadUserAndAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id');
      _currentRole = prefs.getString('role');
      if (_currentUserId != null) {
        await _fetchAssignments();
      }
    } catch (e) {
      print('Error loading user and assignments: $e');
    }
  }

  Future<void> _fetchAssignments() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final assignments = await _apiService.getTaskAssignments(_currentUserId!);
      setState(() {
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching assignments: $e')),
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
    print('🔔 AssignTasksScreen - build, hasUnread: $_hasUnreadNotifications');
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
                  color: Color(0xFF7DF9FF),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
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
                        color: const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          color: Color(0xFF7DF9FF),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CommonNotificationIcon(
                    hasUnreadNotifications: _hasUnreadNotifications,
                    onNotificationCleared: () {
                      setState(() {
                        _hasUnreadNotifications = false;
                      });
                    },
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
              child: Column(
                children: [
                  // Task assignments list
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7DF9FF)),
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskAssignmentItem(TaskAssignment assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar for assigner
          CircleAvatar(
            backgroundColor: const Color(0xFF7DF9FF),
            child: Text(
              assignment.assignerName[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Task Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assigner and Assignee
                Row(
                  children: [
                    Text(
                      assignment.assignerName,
                      style: const TextStyle(
                        color: Color(0xFF7DF9FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      ' → ',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      assignment.assigneeName,
                      style: const TextStyle(
                        color: Color(0xFFFFB86B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Task Name with Priority Dot
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(assignment.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        assignment.taskName,
                        style: const TextStyle(
                          color: Color(0xFF7DF9FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Due Date
                Text(
                  'Due: ${assignment.dueDate.toString().split(' ')[0]}',
                  style: TextStyle(
                    color: _getPriorityColor(assignment.priority),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Edit Button
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF7DF9FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () {
                Navigator.push(
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
              },
              icon: const Icon(
                Icons.edit,
                color: Color(0xFF0F172A),
                size: 16,
              ),
              label: const Text(
                'Edit',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 