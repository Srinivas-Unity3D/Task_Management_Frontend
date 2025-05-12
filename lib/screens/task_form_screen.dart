import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;
  final String? assignedTo;

  const TaskFormScreen({
    Key? key,
    this.task,
    this.assignedTo,
  }) : super(key: key);

  @override
  _TaskFormScreenState createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _apiService = ApiService();
  
  DateTime? _deadline;
  TimeOfDay? _deadlineTime;
  DateTime? _alarmStartDate;
  TimeOfDay? _alarmStartTime;
  String? _priority;
  String? _frequency;
  bool _isLoading = false;
  final _assignedToController = TextEditingController();
  List<String> _users = [];

  @override
  void initState() {
    super.initState();
    if (widget.assignedTo != null) {
      _assignedToController.text = widget.assignedTo!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Create Task' : 'Edit Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_deadline == null
                          ? 'Set Deadline'
                          : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _deadline ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _deadline = date);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(_deadlineTime == null
                          ? 'Set Time'
                          : '${_deadlineTime!.hour}:${_deadlineTime!.minute.toString().padLeft(2, '0')}'),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _deadlineTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() => _deadlineTime = time);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['Low', 'Medium', 'High']
                    .map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _priority = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _assignedToController,
                decoration: const InputDecoration(labelText: 'Assign To'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an assignee';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Add Alarm Settings Section
              const Text(
                'Alarm Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_alarmStartDate == null
                          ? 'Set Alarm Date'
                          : '${_alarmStartDate!.day}/${_alarmStartDate!.month}/${_alarmStartDate!.year}'),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _alarmStartDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _alarmStartDate = date);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(_alarmStartTime == null
                          ? 'Set Alarm Time'
                          : '${_alarmStartTime!.hour}:${_alarmStartTime!.minute.toString().padLeft(2, '0')}'),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _alarmStartTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() => _alarmStartTime = time);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _frequency,
                decoration: const InputDecoration(labelText: 'Alarm Frequency'),
                items: [
                  '30 minutes',
                  '1 hour',
                  '2 hours',
                  '4 hours',
                  '6 hours',
                  '12 hours',
                  'Daily',
                ].map((frequency) => DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency),
                    )).toList(),
                onChanged: (value) {
                  setState(() => _frequency = value);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.task == null ? 'Create Task' : 'Update Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Convert form values to API parameters
        final title = _titleController.text;
        final description = _descriptionController.text;
        final assignedTo = _assignedToController.text;
        
        // Get current user as assignedBy
        final prefs = await SharedPreferences.getInstance();
        final assignedBy = prefs.getString('username') ?? 'Unknown';
        
        // Use deadline or fallback to current time + 1 day
        final deadline = _deadline ?? DateTime.now().add(const Duration(days: 1));
        
        // Use priority or fallback to 'Medium'
        final priority = _priority ?? 'Medium';
        
        // Default status is 'pending'
        const status = 'pending';
        
        // Create alarm settings if provided
        Map<String, dynamic>? alarmSettings;
        if (_alarmStartDate != null && _alarmStartTime != null && _frequency != null) {
          alarmSettings = {
            'start_date': _alarmStartDate!.toIso8601String(),
            'start_time': '${_alarmStartTime!.hour.toString().padLeft(2, '0')}:${_alarmStartTime!.minute.toString().padLeft(2, '0')}',
            'frequency': _frequency,
          };
        }

        if (widget.task != null) {
          await _apiService.updateTask(
            taskId: widget.task!.taskId,
            title: title,
            description: description,
            assignedTo: assignedTo,
            assignedBy: assignedBy,
            deadline: deadline,
            priority: priority,
            status: status,
            alarmSettings: alarmSettings,
            currentUser: "Some user"
          );
        } else {
          await _apiService.createTask(
            title: title,
            description: description,
            assignedTo: assignedTo,
            assignedBy: assignedBy,
            deadline: deadline,
            priority: priority,
            status: status,
            alarmSettings: alarmSettings,
          );
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
} 