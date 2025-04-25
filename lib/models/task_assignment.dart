class TaskAssignment {
  final String assignerId;
  final String assignerName;
  final String assignerRole;
  final String assigneeId;
  final String assigneeName;
  final String assigneeRole;
  final String taskName;
  final DateTime dueDate;
  final String priority;
  final String currentTask;

  TaskAssignment({
    required this.assignerId,
    required this.assignerName,
    required this.assignerRole,
    required this.assigneeId,
    required this.assigneeName,
    required this.assigneeRole,
    required this.taskName,
    required this.dueDate,
    required this.priority,
    required this.currentTask,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      assignerId: json['assigner_id'],
      assignerName: json['assigner_name'],
      assignerRole: json['assigner_role'],
      assigneeId: json['assignee_id'],
      assigneeName: json['assignee_name'],
      assigneeRole: json['assignee_role'],
      taskName: json['task_name'],
      dueDate: DateTime.parse(json['due_date']),
      priority: json['priority'],
      currentTask: json['current_task'],
    );
  }
} 