import 'task.dart';

class TaskStats {
  final int totalTasks;
  final int pendingTasks;
  final int inProgressTasks;
  final int completedTasks;
  final int snoozedTasks;
  final Map<TaskPriority, int> tasksByPriority;

  TaskStats({
    required this.totalTasks,
    required this.pendingTasks,
    required this.inProgressTasks,
    required this.completedTasks,
    required this.snoozedTasks,
    required this.tasksByPriority,
  });

  factory TaskStats.fromTasks(List<Task> tasks) {
    final Map<TaskPriority, int> priorityMap = {
      TaskPriority.low: 0,
      TaskPriority.medium: 0,
      TaskPriority.high: 0,
    };

    int pending = 0;
    int inProgress = 0;
    int completed = 0;
    int snoozed = 0;

    for (final task in tasks) {
      // Count by status
      switch (task.status) {
        case TaskStatus.pending:
          pending++;
          break;
        case TaskStatus.inProgress:
          inProgress++;
          break;
        case TaskStatus.completed:
          completed++;
          break;
        case TaskStatus.snoozed:
          snoozed++;
          break;
      }

      // Count by priority
      priorityMap[task.priority] = (priorityMap[task.priority] ?? 0) + 1;
    }

    return TaskStats(
      totalTasks: tasks.length,
      pendingTasks: pending,
      inProgressTasks: inProgress,
      completedTasks: completed,
      snoozedTasks: snoozed,
      tasksByPriority: priorityMap,
    );
  }

  double get completionRate => 
      totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

  int get activeTasks => pendingTasks + inProgressTasks;

  Map<String, dynamic> toJson() {
    return {
      'total_tasks': totalTasks,
      'pending_tasks': pendingTasks,
      'in_progress_tasks': inProgressTasks,
      'completed_tasks': completedTasks,
      'snoozed_tasks': snoozedTasks,
      'completion_rate': completionRate,
      'active_tasks': activeTasks,
      'tasks_by_priority': {
        'high': tasksByPriority[TaskPriority.high],
        'medium': tasksByPriority[TaskPriority.medium],
        'low': tasksByPriority[TaskPriority.low],
      },
    };
  }
} 