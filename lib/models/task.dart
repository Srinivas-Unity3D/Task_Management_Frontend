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
      taskId: json['task_id'],
      title: json['title'],
      description: json['description'] ?? '',
      deadline: DateTime.parse(json['deadline']),
      priority: _parsePriority(json['priority']),
      status: _parseStatus(json['status']),
      assignedBy: json['assigned_by'],
      assignedTo: json['assigned_to'],
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

  static TaskPriority _parsePriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
        return TaskPriority.medium;
      case 'high':
        return TaskPriority.high;
      default:
        return TaskPriority.medium;
    }
  }

  static TaskStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return TaskStatus.pending;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'snoozed':
        return TaskStatus.snoozed;
      default:
        return TaskStatus.pending;
    }
  }
} 