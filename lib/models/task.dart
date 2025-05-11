import 'package:flutter/material.dart';

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
  final DateTime? completedAt;
  final DateTime? alarmStartDate;
  final TimeOfDay? alarmStartTime;
  final String? alarmFrequency;

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
    this.completedAt,
    this.alarmStartDate,
    this.alarmStartTime,
    this.alarmFrequency,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? parseAlarmStartDate;
    TimeOfDay? parseAlarmStartTime;
    
    if (json['alarm_settings'] != null) {
      final alarmSettings = json['alarm_settings'];
      if (alarmSettings['start_date'] != null) {
        parseAlarmStartDate = DateTime.parse(alarmSettings['start_date']);
      }
      if (alarmSettings['start_time'] != null) {
        final timeParts = alarmSettings['start_time'].split(':');
        parseAlarmStartTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }
    }

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
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      alarmStartDate: parseAlarmStartDate,
      alarmStartTime: parseAlarmStartTime,
      alarmFrequency: json['alarm_settings']?['frequency'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> alarmSettings = {};
    if (alarmStartDate != null) {
      alarmSettings['start_date'] = alarmStartDate!.toIso8601String().split('T')[0];
    }
    if (alarmStartTime != null) {
      alarmSettings['start_time'] = '${alarmStartTime!.hour.toString().padLeft(2, '0')}:${alarmStartTime!.minute.toString().padLeft(2, '0')}:00';
    }
    if (alarmFrequency != null) {
      alarmSettings['frequency'] = alarmFrequency;
    }

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
      'completed_at': completedAt?.toIso8601String(),
      'alarm_settings': alarmSettings.isNotEmpty ? alarmSettings : null,
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