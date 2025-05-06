class TaskAssignment {
  final String taskId;
  final String taskName;
  final String description;
  final String assignerName;
  final String assigneeName;
  final String assigneeRole;
  final DateTime dueDate;
  final String priority;
  final String currentTask;

  TaskAssignment({
    required this.taskId,
    required this.taskName,
    required this.description,
    required this.assignerName,
    required this.assigneeName,
    required this.assigneeRole,
    required this.dueDate,
    required this.priority,
    required this.currentTask,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      taskId: json['task_id'],
      taskName: json['task_name'],
      description: json['description'],
      assignerName: json['assigner_name'],
      assigneeName: json['assignee_name'],
      assigneeRole: json['assignee_role'] ?? 'Developer',
      dueDate: DateTime.parse(json['due_date']),
      priority: json['priority'],
      currentTask: json['current_task'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'task_name': taskName,
      'description': description,
      'assigner_name': assignerName,
      'assignee_name': assigneeName,
      'assignee_role': assigneeRole,
      'due_date': dueDate.toIso8601String(),
      'priority': priority,
      'current_task': currentTask,
    };
  }
} 