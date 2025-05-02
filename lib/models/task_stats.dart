import 'task.dart';

class TaskStats {
  final int activeTasks;
  final int pendingTasks;
  final int inProgressTasks;
  final int completedTasks;
  final int snoozedTasks;

  TaskStats({
    required this.activeTasks,
    required this.pendingTasks,
    required this.inProgressTasks,
    required this.completedTasks,
    required this.snoozedTasks,
  });

  factory TaskStats.fromTasks(List<Task> tasks) {
    int active = 0;
    int pending = 0;
    int inProgress = 0;
    int completed = 0;
    int snoozed = 0;

    for (var task in tasks) {
      switch (task.status) {
        case TaskStatus.pending:
          pending++;
          active++;
          break;
        case TaskStatus.inProgress:
          inProgress++;
          active++;
          break;
        case TaskStatus.completed:
          completed++;
          break;
        case TaskStatus.snoozed:
          snoozed++;
          break;
      }
    }

    return TaskStats(
      activeTasks: active,
      pendingTasks: pending,
      inProgressTasks: inProgress,
      completedTasks: completed,
      snoozedTasks: snoozed,
    );
  }

  double get completionRate => 
      activeTasks > 0 ? (completedTasks / activeTasks) : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'active_tasks': activeTasks,
      'pending_tasks': pendingTasks,
      'in_progress_tasks': inProgressTasks,
      'completed_tasks': completedTasks,
      'snoozed_tasks': snoozedTasks,
      'completion_rate': completionRate,
    };
  }
} 