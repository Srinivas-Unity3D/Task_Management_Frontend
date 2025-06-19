import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../models/task.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/notification_firebase_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../theme/colors.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/dashboard/side_panel.dart';
import '../widgets/filter_panel.dart';
import './create_task_screen.dart';
import '../services/socket_service.dart';
import './notifications_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({Key? key}) : super(key: key);

  @override
  _MyTasksScreenState createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final NotificationFirebaseService _notificationService = NotificationFirebaseService();
  // final AudioService _audioService = AudioService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentRole;
  String? _currentUsername;
  OverlayEntry? _filterOverlay;
  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    print('📋 MyTasksScreen - Initializing...');
    _loadUserAndTasks();
    _setupSocketListeners();
    _checkUnreadNotifications();
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
      print('❌ [MyTasks] Error checking unread notifications: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUnreadNotifications();
  }

  void _setupSocketListeners() {
    print('📋 MyTasksScreen - Setting up socket listeners');
    // Remove any existing listeners
    // _socketService.removeTaskNotificationListener(_handleTaskNotification);
    _socketService.removeDashboardUpdateListener(_handleDashboardUpdate);

    // Add new listeners
    // _socketService.listenToTaskNotifications(_handleTaskNotification);
    _socketService.listenToDashboardUpdates(_handleDashboardUpdate);
    print('📋 MyTasksScreen - Socket listeners setup complete');
  }

  // void _handleTaskNotification(dynamic data) {
  //   if (!mounted) {
  //     print('❌ [MyTasks] Widget not mounted, skipping notification');
  //     return;
  //   }
  //
  //   try {
  //     print('📋 [MyTasks] Processing task notification: $data');
  //     print('📋 [MyTasks] Current user: $_currentUsername');
  //     print('📋 [MyTasks] Notification sender: ${data['task']?['updated_by'] ?? data['task']?['assigned_by']}');
  //     print('📋 [MyTasks] Task data: ${data['task']}');
  //
  //     // Only play sound and vibrate if the notification is from another user
  //     final sender = data['task']?['updated_by'] ?? data['task']?['assigned_by'];
  //     if (sender != _currentUsername) {
  //       print('🔔 [MyTasks] Playing notification sound...');
  //       // _audioService.playNotificationSound();
  //
  //       // Show notification in notification bar
  //       print('🔔 [MyTasks] Showing system notification...');
  //       _notificationService.showNotification(
  //         title: data['type'] == 'task_created' ? 'New Task Assigned' : 'Task Updated',
  //         body: data['task']?['title'] ?? 'You have a new task update',
  //         payload: json.encode(data),
  //       );
  //     } else {
  //       print('👤 [MyTasks] Skipping notification - from current user');
  //     }
  //
  //     // Update task list and show notification badge
  //     print('🔄 [MyTasks] Updating task list and badge...');
  //     _notificationService.setUnreadState(true);
  //     if (mounted) {
  //       setState(() {
  //         _hasUnreadNotifications = true;
  //       });
  //     }
  //     _loadTasks();
  //     print('✅ [MyTasks] Notification handling complete');
  //   } catch (e) {
  //     print('❌ [MyTasks] Error handling notification: $e');
  //     print('❌ [MyTasks] Error stack trace: ${StackTrace.current}');
  //   }
  // }

  void _handleDashboardUpdate(dynamic data) {
    if (mounted) {
      print('📋 MyTasksScreen - Received dashboard update');
      // Refresh tasks list
      _loadTasks();
    }
  }

  @override
  void dispose() {
    print('📋 MyTasksScreen - Disposing...');
    // _socketService.removeTaskNotificationListener(_handleTaskNotification);
    _socketService.removeDashboardUpdateListener(_handleDashboardUpdate);
    _removeFilterPanel();
    super.dispose();
  }

  void _showFilterPanel(BuildContext context, Offset buttonPosition) {
    _removeFilterPanel();
    final buttonSize = 40.0;
    final headerHeight = 80.0;
    final topPadding = 16.0;
    final extraTopOffset = 20.0;
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
            right: 75,
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
    _removeFilterPanel();
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
      if (_currentUsername == null) {
        print('Error: Current username is null');
        return;
      }
      final response = await _apiService.getTasks(
          username: _currentUsername!, role: _currentRole ?? '');
      print('Raw tasks response: ${response['data']}'); // Debug log
      if (response['success']) {
        final tasksJson = response['data'] as List;
        setState(() {
          _tasks = tasksJson
              .map((task) => Task.fromJson(task))
              .where((task) => task.assignedTo == _currentUsername)
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

  Color _getPriorityColorString(String priority) {
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

  Widget _buildTaskCard(Task task) {
    String _formatDate(DateTime? date) {
      if (date == null) return 'N/A';

      // Convert to IST (UTC+5:30)
      final istDate = date.add(const Duration(hours: 5, minutes: 30));

      // Convert to 12-hour format with AM/PM
      final hour = istDate.hour % 12 == 0 ? 12 : istDate.hour % 12;
      final period = istDate.hour >= 12 ? 'PM' : 'AM';
      final time = '${hour.toString().padLeft(2, '0')}:${istDate.minute.toString().padLeft(2, '0')} $period';
      return time;
    }

    String _formatDateOnly(DateTime? date) {
      if (date == null) return 'N/A';

      // Convert to IST (UTC+5:30)
      final istDate = date.add(const Duration(hours: 5, minutes: 30));
      // final fullDate = '${istDate.year}-${istDate.month.toString().padLeft(2, '0')}-${istDate.day.toString().padLeft(2, '0')}';
      final fullDate = '${istDate.day.toString().padLeft(2, '0')}-${istDate.month.toString().padLeft(2, '0')}-${istDate.year}';
      return fullDate;
    }

    // Determine the status emoji based on status
    String _getStatusEmoji(String status) {
      switch (status.toLowerCase()) {
        case 'completed':
          return '🟢';
        case 'pending':
          return '🔴';
        case 'in_progress':
          return '🔵';
        default:
          return '🟡';
      }
    }

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateTaskScreen(
              isEditMode: true,
              taskId: task.taskId,
              initialTitle: task.title,
              initialDescription: task.description,
              initialAssignee: task.assignedTo,
              initialAssigner: task.assignedBy,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.borderColor.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Icon Circle
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.inputBackground,
              child: Icon(
                Icons.task,
                color: AppColors.accentCyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            // Task Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Title
                  Text(
                    task.title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Task Description
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📝 ',
                        style: TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: Text(
                          task.description.isNotEmpty
                              ? task.description
                              : 'No description available',
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Assigner Info
                  Row(
                    children: [
                      const Text(
                        'Assigned By: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          task.assignedBy,
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          ' (${task.assignedByRole})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Status and Priority
                  Row(
                    children: [
                      // Priority badge
                      const Text(
                        'Priority: ',
                        style: TextStyle(fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColorString(task.priority.toString().split('.').last).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.priority.toString().split('.').last,
                          style: TextStyle(
                            color: _getPriorityColorString(task.priority.toString().split('.').last),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge
                      Text(
                        _getStatusEmoji(task.status.toString().split('.').last),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task.status.toString().split('.').last).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.status.toString().split('.').last,
                          style: TextStyle(
                            color: _getStatusColor(task.status.toString().split('.').last),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Created Time and Due Date
                  Row(
                    children: [
                      const Text(
                        '⏰ ',
                        style: TextStyle(fontSize: 12),
                      ),
                      Flexible(
                        flex: 3, // Give "Created" more priority
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 150), // Ensure enough space for date and time
                          child: Text(
                            'Created: ${_formatDate(task.createdAt)} | ${_formatDateOnly(task.createdAt)}',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '📅 ',
                        style: TextStyle(fontSize: 12),
                      ),
                      Flexible(
                        flex: 2, // "Due" gets less priority
                        child: Text(
                          'Due: ${_formatDateOnly(task.deadline)}',
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildTaskCard(Task task) {
  //   String _formatDate(DateTime? date) {
  //     if (date == null) return 'N/A';
  //
  //     // Convert to IST (UTC+5:30)
  //     final istDate = date.add(const Duration(hours: 5, minutes: 30));
  //
  //     // Convert to 12-hour format with AM/PM
  //     final hour = istDate.hour % 12 == 0 ? 12 : istDate.hour % 12;
  //     final period = istDate.hour >= 12 ? 'PM' : 'AM';
  //     final time = '${hour.toString().padLeft(2, '0')}:${istDate.minute.toString().padLeft(2, '0')} $period';
  //     return time;
  //   }
  //
  //   String _formatDateOnly(DateTime? date) {
  //     if (date == null) return 'N/A';
  //
  //     // Convert to IST (UTC+5:30)
  //     final istDate = date.add(const Duration(hours: 5, minutes: 30));
  //     final fullDate = '${istDate.year}-${istDate.month.toString().padLeft(2, '0')}-${istDate.day.toString().padLeft(2, '0')}';
  //     return fullDate;
  //   }
  //
  //   // Determine the status emoji based on status
  //   String _getStatusEmoji(String status) {
  //     switch (status.toLowerCase()) {
  //       case 'completed':
  //         return '🟢';
  //       case 'pending':
  //         return '🔴';
  //       case 'in_progress':
  //         return '🔵';
  //       default:
  //         return '🟡';
  //     }
  //   }
  //
  //   return InkWell(
  //     onTap: () async {
  //       final result = await Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => CreateTaskScreen(
  //             isEditMode: true,
  //             taskId: task.taskId,
  //             initialTitle: task.title,
  //             initialDescription: task.description,
  //             initialAssignee: task.assignedTo,
  //             initialAssigner: task.assignedBy,
  //             initialPriority: task.priority.toString().split('.').last,
  //             initialDueDate: task.deadline,
  //             initialStatus: task.status.toString().split('.').last,
  //           ),
  //         ),
  //       );
  //       if (result == true) {
  //         await _loadTasks();
  //       }
  //     },
  //     borderRadius: BorderRadius.circular(12),
  //     child: Container(
  //       margin: const EdgeInsets.only(bottom: 16),
  //       padding: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: AppColors.cardBackground,
  //         borderRadius: BorderRadius.circular(12),
  //         boxShadow: [
  //           BoxShadow(
  //             color: AppColors.borderColor.withOpacity(0.1),
  //             blurRadius: 4,
  //             offset: Offset(0, 2),
  //           ),
  //         ],
  //       ),
  //       child: Row(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // User Initial Circle
  //           // Task Icon Circle
  //           CircleAvatar(
  //             radius: 20,
  //             backgroundColor: AppColors.inputBackground,
  //             child: Icon(
  //               Icons.task, // Notes icon to represent the task
  //               color: AppColors.accentCyan,
  //               size: 24, // Slightly larger to fit the CircleAvatar
  //             ),
  //           ),
  //           const SizedBox(width: 12),
  //           // Task Details
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 // Task Title
  //                 Text(
  //                   task.title,
  //                   style: const TextStyle(
  //                     color: AppColors.white,
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.w600,
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //                 const SizedBox(height: 4),
  //                 // Task Description
  //                 Row(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     const Text(
  //                       '📝 ',
  //                       style: TextStyle(fontSize: 12),
  //                     ),
  //                     Expanded(
  //                       child: Text(
  //                         task.description.isNotEmpty
  //                             ? task.description
  //                             : 'No description available',
  //                         style: const TextStyle(
  //                           color: AppColors.textGrey,
  //                           fontSize: 12,
  //                         ),
  //                         maxLines: 2,
  //                         overflow: TextOverflow.ellipsis,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 const SizedBox(height: 8),
  //                 // Assigner Info
  //                 Row(
  //                   children: [
  //                     const Text(
  //                       'Assigned To: ',
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         color: AppColors.textGrey,
  //                       ),
  //                     ),
  //                     Text(
  //                       task.assignedTo,
  //                       style: const TextStyle(
  //                         color: AppColors.accentCyan,
  //                         fontSize: 14,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                     const SizedBox(width: 4),
  //                     Text(
  //                       ' (${task.assignedByRole})',
  //                       style: const TextStyle(
  //                         fontSize: 12,
  //                         color: AppColors.textGrey,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 const SizedBox(height: 12),
  //                 // Status and Priority
  //                 Row(
  //                   children: [
  //                     // Priority badge
  //                     const Text(
  //                       'Priority: ',
  //                       style: TextStyle(fontSize: 12),
  //                     ),
  //                     Container(
  //                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                       decoration: BoxDecoration(
  //                         color: _getPriorityColorString(task.priority.toString().split('.').last).withOpacity(0.2),
  //                         borderRadius: BorderRadius.circular(8),
  //                       ),
  //                       child: Text(
  //                         task.priority.toString().split('.').last,
  //                         style: TextStyle(
  //                           color: _getPriorityColorString(task.priority.toString().split('.').last),
  //                           fontSize: 10,
  //                           fontWeight: FontWeight.w500,
  //                         ),
  //                       ),
  //                     ),
  //                     const SizedBox(width: 8),
  //                     // Status badge
  //                     Text(
  //                       _getStatusEmoji(task.status.toString().split('.').last),
  //                       style: const TextStyle(fontSize: 12),
  //                     ),
  //                     const SizedBox(width: 4),
  //                     Container(
  //                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                       decoration: BoxDecoration(
  //                         color: _getStatusColor(task.status.toString().split('.').last).withOpacity(0.2),
  //                         borderRadius: BorderRadius.circular(8),
  //                       ),
  //                       child: Text(
  //                         task.status.toString().split('.').last,
  //                         style: TextStyle(
  //                           color: _getStatusColor(task.status.toString().split('.').last),
  //                           fontSize: 10,
  //                           fontWeight: FontWeight.w500,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 const SizedBox(height: 8),
  //                 // Created Time and Due Date
  //                 Row(
  //                   children: [
  //                     const Text(
  //                       '⏰ ',
  //                       style: TextStyle(fontSize: 12),
  //                     ),
  //                     Text(
  //                       'Created: ${_formatDateOnly(task.createdAt)} | ${_formatDate(task.createdAt)}',
  //                       style: const TextStyle(
  //                         color: AppColors.textGrey,
  //                         fontSize: 10,
  //                       ),
  //                     ),
  //                     const SizedBox(width: 16),
  //                     const Text(
  //                       '📅 ',
  //                       style: TextStyle(fontSize: 12),
  //                     ),
  //                     Text(
  //                       'Due: ${_formatDateOnly(task.deadline)}',
  //                       style: const TextStyle(
  //                         color: AppColors.textGrey,
  //                         fontSize: 10,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildTaskCard(Task task) {
  //   String _formatDate(DateTime date) {
  //     return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  //   }
  //
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 16),
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: AppColors.cardBackground,
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             CircleAvatar(
  //               radius: 20,
  //               backgroundColor: AppColors.inputBackground,
  //               child: Text(
  //                 task.assignedBy[0].toUpperCase(),
  //                 style: const TextStyle(
  //                   color: AppColors.accentCyan,
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     task.assignedBy,
  //                     style: const TextStyle(
  //                       color: AppColors.accentCyan,
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w600,
  //                     ),
  //                   ),
  //                   Text(
  //                     task.assignedByRole,
  //                     style: const TextStyle(
  //                       color: AppColors.textGrey,
  //                       fontSize: 12,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             Container(
  //               height: 32,
  //               decoration: BoxDecoration(
  //                 color: AppColors.accentCyan,
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //               child: TextButton.icon(
  //                 style: TextButton.styleFrom(
  //                   padding: const EdgeInsets.symmetric(horizontal: 12),
  //                 ),
  //                 onPressed: () async {
  //                   final result = await Navigator.push(
  //                     context,
  //                     MaterialPageRoute(
  //                       builder: (context) => CreateTaskScreen(
  //                         isEditMode: true,
  //                         taskId: task.taskId,
  //                         initialTitle: task.title,
  //                         initialDescription: task.description,
  //                         initialAssignee: task.assignedTo,
  //                         initialAssigner: task.assignedBy, // Added
  //                         initialPriority: task.priority.toString().split('.').last,
  //                         initialDueDate: task.deadline,
  //                         initialStatus: task.status.toString().split('.').last,
  //                       ),
  //                     ),
  //                   );
  //                   if (result == true) {
  //                     await _loadTasks();
  //                   }
  //                 },
  //                 icon: const Icon(
  //                   Icons.edit,
  //                   color: AppColors.background,
  //                   size: 16,
  //                 ),
  //                 label: const Text(
  //                   'View/Edit',
  //                   style: TextStyle(
  //                     color: AppColors.background,
  //                     fontSize: 12,
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 12),
  //         Row(
  //           children: [
  //             Text(
  //               'Task: ',
  //               style: TextStyle(
  //                 color: AppColors.textGrey,
  //                 fontSize: 12,
  //               ),
  //             ),
  //             Expanded(
  //               child: Text(
  //                 task.title,
  //                 style: TextStyle(
  //                   color: AppColors.white,
  //                   fontSize: 12,
  //                 ),
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 4),
  //         Row(
  //           children: [
  //             // Priority badge
  //             Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  //               decoration: BoxDecoration(
  //                 color: _getPriorityColorString(task.priority.toString().split('.').last).withOpacity(0.2),
  //                 borderRadius: BorderRadius.circular(4),
  //               ),
  //               child: Text(
  //                 task.priority.toString().split('.').last,
  //                 style: TextStyle(
  //                   color: _getPriorityColorString(task.priority.toString().split('.').last),
  //                   fontSize: 10,
  //                   fontWeight: FontWeight.w500,
  //                 ),
  //               ),
  //             ),
  //             const SizedBox(width: 8),
  //             // Status badge
  //             Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  //               decoration: BoxDecoration(
  //                 color: _getStatusColor(task.status.toString().split('.').last).withOpacity(0.2),
  //                 borderRadius: BorderRadius.circular(4),
  //               ),
  //               child: Text(
  //                 task.status.toString().split('.').last,
  //                 style: TextStyle(
  //                   color: _getStatusColor(task.status.toString().split('.').last),
  //                   fontSize: 10,
  //                   fontWeight: FontWeight.w500,
  //                 ),
  //               ),
  //             ),
  //             const SizedBox(width: 8),
  //             // Due date
  //             Icon(Icons.calendar_today, size: 12, color: AppColors.textGrey),
  //             const SizedBox(width: 2),
  //             Text(
  //               _formatDate(task.deadline),
  //               style: TextStyle(
  //                 color: AppColors.textGrey,
  //                 fontSize: 10,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _downloadTasks() async {
    try {
      setState(() => _isLoading = true);  // Show loading indicator
      
      // Get the current tasks that are displayed
      if (_filteredTasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tasks available to download'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create CSV content from filtered tasks
      String csvData = 'Title,Description,Deadline,Priority,Status\n';
      for (var task in _filteredTasks) {
        // Escape commas and quotes in text fields
        String title = task.title.replaceAll('"', '""');
        String description = task.description.replaceAll('"', '""');
        String deadline = task.deadline.toString().split(' ')[0]; // Get just the date
        String priority = task.priority.toString().split('.').last;
        String status = task.status.toString().split('.').last;
        
        csvData += '"$title","$description","$deadline","$priority","$status"\n';
      }

      // Get the download directory
      Directory? directory;
      if (Platform.isAndroid) {
        // Get the downloads directory on Android
        directory = Directory('/storage/emulated/0/Download');
      } else {
        // For iOS, we'll use the documents directory
        directory = await getApplicationDocumentsDirectory();
      }

      // Create the file
      String fileName = 'tasks_${DateTime.now().millisecondsSinceEpoch}.csv';
      final File file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      // Show success message with file location
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tasks downloaded to: ${file.path}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () async {
                // Open the file
                try {
                  await OpenFile.open(file.path);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open file: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading tasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);  // Hide loading indicator
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
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
        currentRoute: '/my-tasks',
      ),
      body: Column(
        children: [
          CommonAppBar(
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            hasUnreadNotifications: _hasUnreadNotifications,
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
                      final RenderBox button = context.findRenderObject() as RenderBox;
                      final Offset buttonPosition = button.localToGlobal(Offset.zero);
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
                    icon: const Icon(Icons.download, color: AppColors.accentCyan),
                    onPressed: _downloadTasks,
                    tooltip: 'Download Tasks',
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
                itemBuilder: (context, index) => _buildTaskCard(_filteredTasks[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}