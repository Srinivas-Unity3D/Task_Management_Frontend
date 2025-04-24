import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/custom_text_field.dart';
import '../models/task.dart';
import '../widgets/role_dropdown.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({Key? key}) : super(key: key);

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _apiService = ApiService();
  final _audioPlayer = AudioPlayer();
  late final AudioRecorder _audioRecorder;
  
  String? _selectedAssignee;
  String _priority = 'Low';
  DateTime? _dueDate;
  DateTime? _alarmStartDate;
  TimeOfDay? _alarmStartTime;
  String _alarmFrequency = '30 minutes';
  TaskStatus _status = TaskStatus.pending;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedFilePath;
  List<String> _users = [];
  bool _isLoadingUsers = true;
  String? _currentUsername;

  final List<String> _frequencyOptions = const [
    '30 minutes',
    '1 hour',
    '2 hours',
    '4 hours',
    '6 hours',
    '8 hours',
  ];

  final List<String> _priorityOptions = const [
    'Low',
    'Medium',
    'High',
    'Urgent'
  ];

  @override
  void initState() {
    super.initState();
    print('Initializing AudioRecorder...');
    _audioRecorder = AudioRecorder();
    _getCurrentUser();
    _requestPermissions();
  }

  Future<void> _getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUsername = prefs.getString('username');
      await _fetchUsers();
    } catch (e) {
      print('Error getting current user: $e');
    }
  }

  Future<void> _fetchUsers() async {
    try {
      setState(() {
        _isLoadingUsers = true;
      });
      
      final users = await _apiService.getUsers();
      setState(() {
        // Filter out the current user from the list
        _users = users.where((user) => user != _currentUsername).toList();
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('Error fetching users: $e');
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    try {
      print('Requesting permissions...');
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.storage,
      ].request();
      
      print('Permission statuses: $statuses');
      
      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        print('Microphone permission not granted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required for recording')),
        );
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      print('Starting recording process...');
      
      // Create directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final dirPath = '${appDir.path}/recordings';
      await Directory(dirPath).create(recursive: true);
      
      final filePath = '$dirPath/audio_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      print('Will save recording to: $filePath');

      // Configure and start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      print('Recording started successfully');

      setState(() {
        _isRecording = true;
        _recordedFilePath = filePath;
      });
    } catch (e) {
      print('Error in _startRecording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      print('Not currently recording');
      return;
    }

    try {
      print('Stopping recording...');
      final path = await _audioRecorder.stop();
      print('Recording stopped. File saved at: $path');

      setState(() {
        _isRecording = false;
      });

      // Verify file exists
      final file = File(path ?? '');
      if (await file.exists()) {
        print('Recording file exists at: ${file.path}');
      } else {
        print('Warning: Recording file not found at: ${file.path}');
      }
    } catch (e) {
      print('Error in _stopRecording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
    }
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath == null) {
      print('No recording to play');
      return;
    }
    
    try {
      print('Attempting to play recording from: $_recordedFilePath');
      if (_isPlaying) {
        print('Stopping current playback');
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        print('Starting playback');
        await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
        setState(() {
          _isPlaying = true;
        });
        
        // Listen for playback completion
        _audioPlayer.onPlayerComplete.listen((event) {
          print('Playback completed');
          setState(() {
            _isPlaying = false;
          });
        });
      }
    } catch (e) {
      print('Error in _playRecording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play recording: $e')),
      );
    }
  }

  Future<void> _deleteRecording() async {
    if (_recordedFilePath == null) return;
    
    try {
      final file = File(_recordedFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
      setState(() {
        _recordedFilePath = null;
      });
    } catch (e) {
      print('Error deleting recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create New Task',
                  style: TextStyle(
                    color: Color(0xFF7DF9FF),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                // Task Title
                const Text(
                  'Task Title',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _titleController,
                  label: 'Task Title',
                  hint: 'Enter task title',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a task title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Description
                const Text(
                  'Description',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Enter task description',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                // Assignee Dropdown
                const Text(
                  'Assignee',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _isLoadingUsers
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                        ),
                      )
                    : RoleDropdown(
                        label: 'Assignee',
                        hint: 'Select assignee',
                        items: _users,
                        value: _selectedAssignee,
                        onChanged: (value) {
                          setState(() {
                            _selectedAssignee = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an assignee';
                          }
                          return null;
                        },
                      ),
                const SizedBox(height: 16),
                // Priority and Due Date Row
                Row(
                  children: [
                    // Priority
                    Expanded(
                      child: RoleDropdown(
                        label: 'Priority',
                        hint: 'Select priority',
                        items: _priorityOptions,
                        value: _priority,
                        onChanged: (value) {
                          setState(() {
                            _priority = value ?? 'Low';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select priority';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Due Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Due Date',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF7DF9FF),
                                        surface: Color(0xFF0D1526),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (date != null) {
                                setState(() {
                                  _dueDate = date;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1526),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF1E293B)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _dueDate != null
                                        ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                        : 'dd/mm/yyyy',
                                    style: TextStyle(
                                      color: _dueDate != null ? Colors.white : const Color(0xFF94A3B8),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, color: Color(0xFF94A3B8), size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Alarm Section
                const Text(
                  'Alarm',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                // Alarm Start Date and Time
                Row(
                  children: [
                    // Start Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Date',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF7DF9FF),
                                        surface: Color(0xFF0D1526),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (date != null) {
                                setState(() {
                                  _alarmStartDate = date;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1526),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF1E293B)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _alarmStartDate != null
                                        ? '${_alarmStartDate!.day}/${_alarmStartDate!.month}/${_alarmStartDate!.year}'
                                        : 'Select date',
                                    style: TextStyle(
                                      color: _alarmStartDate != null ? Colors.white : const Color(0xFF94A3B8),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, color: Color(0xFF94A3B8), size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Start Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Time',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF7DF9FF),
                                        surface: Color(0xFF0D1526),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (time != null) {
                                setState(() {
                                  _alarmStartTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1526),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF1E293B)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _alarmStartTime != null
                                        ? _alarmStartTime!.format(context)
                                        : 'Select time',
                                    style: TextStyle(
                                      color: _alarmStartTime != null ? Colors.white : const Color(0xFF94A3B8),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(Icons.access_time, color: Color(0xFF94A3B8), size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Alarm Frequency
                RoleDropdown(
                  label: 'Frequency',
                  hint: 'Select frequency',
                  items: _frequencyOptions,
                  value: _alarmFrequency,
                  onChanged: (value) {
                    setState(() {
                      _alarmFrequency = value ?? '30 minutes';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a frequency';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Status
                const Text(
                  'Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusButton(TaskStatus.pending, 'Pending'),
                    const SizedBox(width: 12),
                    _buildStatusButton(TaskStatus.inProgress, 'In Progress'),
                    const SizedBox(width: 12),
                    _buildStatusButton(TaskStatus.completed, 'Completed'),
                  ],
                ),
                const SizedBox(height: 16),
                // Voice Notes
                const Text(
                  'Voice Notes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      // Record Button
                      ElevatedButton.icon(
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording ? Colors.red : AppColors.accentCyan,
                          foregroundColor: AppColors.background,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                        label: Text(
                          _isRecording ? 'Stop Recording' : 'Start Recording',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_recordedFilePath != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _playRecording,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentCyan,
                                  foregroundColor: AppColors.background,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                                label: Text(
                                  _isPlaying ? 'Stop Playing' : 'Play Recording',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _deleteRecording,
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Recording',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Attachments
                const Text(
                  'Attachments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    // TODO: Implement file picking
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1526),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.add,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Choose files...',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: _handleCreateTask,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF7DF9FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Create Task',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButton(TaskStatus status, String label) {
    final isSelected = _status == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _status = status;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7DF9FF) : const Color(0xFF0D1526),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF7DF9FF) : const Color(0xFF1E293B),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleCreateTask() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        String? audioBase64;
        if (_recordedFilePath != null) {
          final file = File(_recordedFilePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            audioBase64 = base64Encode(bytes);
          }
        }

        final response = await _apiService.createTask(
          title: _titleController.text,
          description: _descriptionController.text,
          assignedTo: _selectedAssignee!,
          assignedBy: _currentUsername!,
          deadline: _dueDate!.toIso8601String(),
          priority: _priority.toLowerCase(),
          status: _status.toString().split('.').last,
          audioNote: audioBase64,
        );

        if (response['success']) {
          Navigator.pop(context);
        }
      } catch (e) {
        print('Error creating task: $e');
        // Show error message to user
      }
    }
  }
} 