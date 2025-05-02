import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/dashboard/side_panel.dart';
import '../models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './create_task_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({Key? key}) : super(key: key);

  @override
  _MyTasksScreenState createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final ApiService _apiService = ApiService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Task> _tasks = [];
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;
  String? _currentUserId;
  String? _currentRole;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadUserAndTasks();
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

      final response = await _apiService.getTasks(username: _currentUsername!, role: _currentRole ?? '');
      if (response['success']) {
        final tasksJson = response['data'] as List;
        setState(() {
          _tasks = tasksJson
              .map((task) => Task.fromJson(task))
              .where((task) => task.assignedTo == _currentUsername)  // Filter tasks assigned to current user
              .toList();
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
        currentRoute: '/my-tasks',
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
                    icon: const Icon(Icons.filter_list, color: AppColors.accentCyan),
                    onPressed: () {
                      // TODO: Implement filter functionality
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
                    icon: const Icon(Icons.download, color: AppColors.accentCyan),
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
                    child: CircularProgressIndicator(color: AppColors.accentCyan),
                  )
                : _tasks.isEmpty
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
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) => _buildTaskCard(_tasks[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
} 