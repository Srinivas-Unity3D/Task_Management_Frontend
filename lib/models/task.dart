enum TaskPriority {
  low,
  medium,
  high,
  urgent
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
  final String assignedByRole;
  final String assignedTo;
  final String assignedToRole;
  final DateTime? completedAt;

  Task({
    required this.taskId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.priority,
    required this.status,
    required this.assignedBy,
    required this.assignedByRole,
    required this.assignedTo,
    required this.assignedToRole,
    this.completedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      taskId: json['task_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      deadline: DateTime.parse(json['deadline'] ?? DateTime.now().toIso8601String()),
      priority: _parsePriority(json['priority'] ?? 'medium'),
      status: _parseStatus(json['status'] ?? 'pending'),
      assignedBy: json['assigned_by'] ?? '',
      assignedByRole: json['assigned_by_role'] ?? '',
      assignedTo: json['assigned_to'] ?? '',
      assignedToRole: json['assigned_to_role'] ?? '',
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
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
      'assigned_by_role': assignedByRole,
      'assigned_to': assignedTo,
      'assigned_to_role': assignedToRole,
      'completed_at': completedAt?.toIso8601String(),
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
      case 'urgent':
        return TaskPriority.urgent;
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