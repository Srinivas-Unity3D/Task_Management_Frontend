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
    if (widget.task != null) {
      // Populate form fields with existing task data
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description ?? '';
      
      // Set deadline if available
      if (widget.task!.deadline != null) {
        try {
          _deadline = widget.task!.deadline;
          _deadlineTime = TimeOfDay(hour: widget.task!.deadline.hour, minute: widget.task!.deadline.minute);
        } catch (e) {
          print('Error parsing due date: $e');
        }
      }
      
      // Set priority - convert from enum to string
      _priority = widget.task!.priority.toString().split('.').last;
      
      // Set assigned to
      if (widget.task!.assignedTo != null) {
        _assignedToController.text = widget.task!.assignedTo;
      }
      
      // Fetch alarm settings for this task
      _fetchAlarmSettings();
    } else if (widget.assignedTo != null) {
      _assignedToController.text = widget.assignedTo!;
    }
    
    // Load users list for assignee dropdown
    _loadUsers();
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
                decoration: const InputDecoration(
                  labelText: 'Assign To',
                  hintText: 'Enter username of assignee',
                  suffixIcon: Icon(Icons.person),
                ),
                readOnly: true,
                onTap: () {
                  if (_users.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Loading users list...')),
                    );
                    return;
                  }
                  
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Select Assignee'),
                        content: Container(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(_users[index]),
                                onTap: () {
                                  setState(() {
                                    _assignedToController.text = _users[index];
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                        ],
                      );
                    },
                  );
                },
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
          final response = await _apiService.updateTask(
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
          
          if (!response['success']) {
            throw Exception(response['message'] ?? 'Failed to update task');
          }
          
        } else {
          final response = await _apiService.createTask(
            title: title,
            description: description,
            assignedTo: assignedTo,
            assignedBy: assignedBy,
            deadline: deadline,
            priority: priority,
            status: status,
            alarmSettings: alarmSettings,
          );
          
          if (!response['success']) {
            throw Exception(response['message'] ?? 'Failed to create task');
          }
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

  Future<void> _fetchAlarmSettings() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/${widget.task!.taskId}/alarms'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true && data['alarms'] != null && data['alarms'].isNotEmpty) {
          final alarm = data['alarms'][0]; // Take first alarm
          
          // Parse start date
          if (alarm['start_date'] != null) {
            try {
              _alarmStartDate = DateTime.parse(alarm['start_date']);
            } catch (e) {
              print('Error parsing alarm start date: $e');
            }
          }
          
          // Parse start time
          if (alarm['start_time'] != null) {
            try {
              final timeParts = alarm['start_time'].split(':');
              _alarmStartTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
            } catch (e) {
              print('Error parsing alarm start time: $e');
            }
          }
          
          // Set frequency
          _frequency = alarm['frequency'];
          
          setState(() {}); // Update UI with alarm settings
        }
      }
    } catch (e) {
      print('Error fetching alarm settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadUsers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/users'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['users'] != null) {
          setState(() {
            _users = List<String>.from(data['users'].map((user) => user['username']));
          });
        }
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }
} 