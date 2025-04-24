enum TaskPriority {
  low,
  medium,
  high
}

enum TaskStatus {
  pending,
  inProgress,
  completed,
  snoozed
}

class Task {
  final String taskId;
  final String title;
  final String description;
  final DateTime deadline;
  final TaskPriority priority;
  final TaskStatus status;
  final String assignedBy;
  final String assignedTo;

  Task({
    required this.taskId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.priority,
    required this.status,
    required this.assignedBy,
    required this.assignedTo,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      taskId: json['task_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      deadline: json['deadline'] != null 
          ? DateTime.parse(json['deadline']) 
          : DateTime.now(),
      priority: _getPriorityFromString(json['priority']),
      status: _getStatusFromString(json['status']),
      assignedBy: json['assigned_by']?.toString() ?? '',
      assignedTo: json['assigned_to']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'assigned_by': assignedBy,
      'assigned_to': assignedTo,
    };
  }

  static TaskPriority _getPriorityFromString(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return TaskPriority.high;
      case 'medium':
        return TaskPriority.medium;
      case 'low':
      default:
        return TaskPriority.low;
    }
  }

  static TaskStatus _getStatusFromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'snoozed':
        return TaskStatus.snoozed;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }
} 