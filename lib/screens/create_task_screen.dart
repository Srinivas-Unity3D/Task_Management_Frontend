import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/custom_text_field.dart';
import '../models/task.dart';
import '../models/attachment.dart';
import '../widgets/role_dropdown.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

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
  bool _isLoading = false;

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

  final bool _isEmulatorTestMode = false;  // Set to false for real device testing

  bool _canScroll = true;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  Duration _playbackPosition = Duration.zero;
  Timer? _playbackTimer;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  List<PlatformFile> _selectedFiles = [];
  bool _isUploadingFiles = false;

  @override
  void initState() {
    super.initState();
    print('🎤 [Init] Initializing AudioRecorder...');
    _audioRecorder = AudioRecorder();
    _checkMicrophoneStatus();
    _getCurrentUser();
    _setupAudioPlayer();
    _requestInitialPermissions();
  }

  void _setupAudioPlayer() {
    // Listen to position changes
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _playbackPosition = position;
      });
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
  }

  Future<void> _checkMicrophoneStatus() async {
    try {
      print('\n🎤 [Microphone] Checking microphone status...');
      
      // Check if microphone permission is granted
      final micPermission = await Permission.microphone.status;
      print('🎤 [Microphone] Permission status: $micPermission');
      
      // Check if microphone is available
      final hasRecordingPermission = await _audioRecorder.hasPermission();
      print('🎤 [Microphone] Recording permission: $hasRecordingPermission');
      
      // Check if microphone is currently in use
      final isRecording = await _audioRecorder.isRecording();
      print('🎤 [Microphone] Is currently recording: $isRecording');
      
      if (!hasRecordingPermission) {
        print('❌ [Microphone] No recording permission available');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone access is not available')),
        );
      }
    } catch (e) {
      print('❌ [Microphone] Error checking status: $e');
    }
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
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<bool> _requestStoragePermission() async {
    print('📱 [Permissions] Checking storage permissions...');
    
    // For Android 13 and above
    if (await Permission.photos.request().isGranted &&
        await Permission.videos.request().isGranted &&
        await Permission.audio.request().isGranted) {
      print('✅ [Permissions] Media permissions granted');
      return true;
    }
    
    // For Android 12 and below
    if (await Permission.storage.request().isGranted) {
      print('✅ [Permissions] Storage permission granted');
      return true;
    }

    print('❌ [Permissions] Storage permissions denied');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Storage permission is required to pick files'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    return false;
  }

  Future<void> _pickFiles() async {
    try {
      // Request storage permission first
      if (!await _requestStoragePermission()) {
        print('❌ [Files] Storage permission not granted');
        return;
      }

      setState(() {
        _isUploadingFiles = true;
      });

      print('📁 [Files] Opening file picker...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
        onFileLoading: (FilePickerStatus status) => print('📁 [Files] Picker status: $status'),
      );

      if (result != null) {
        print('📁 [Files] Files selected successfully');
        setState(() {
          _selectedFiles = result.files;
        });
        
        // Print file details for debugging
        for (PlatformFile file in result.files) {
          print('📎 [Files] Selected file:');
          print('  - Name: ${file.name}');
          print('  - Size: ${(file.size / 1024).toStringAsFixed(2)} KB');
          print('  - Extension: ${file.extension}');
          print('  - Path: ${file.path}');
          print('  - Has data: ${file.bytes != null}');
        }
      } else {
        print('📁 [Files] No files selected');
      }
    } catch (e) {
      print('❌ [Files] Error picking files: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploadingFiles = false;
      });
    }
  }

  Future<void> _removeFile(int index) async {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  String _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'txt':
        return '📃';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '🖼️';
      default:
        return '📎';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: (!_isRecording && !_isPlaying) 
              ? const AlwaysScrollableScrollPhysics() 
              : const NeverScrollableScrollPhysics(),
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
                // Alarm Section
                const Text(
                  'Alarm Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // Start Date
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _alarmStartDate ?? DateTime.now(),
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
                              : 'Select Start Date',
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
                const SizedBox(height: 8),
                // Start Time
                GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _alarmStartTime ?? TimeOfDay.now(),
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
                              ? '${_alarmStartTime!.hour.toString().padLeft(2, '0')}:${_alarmStartTime!.minute.toString().padLeft(2, '0')}'
                              : 'Select Start Time',
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
                const SizedBox(height: 8),
                // Frequency Dropdown
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
                        onPressed: _isPlaying ? null : (_isRecording ? _stopRecording : _startRecording),
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
                      if (_isRecording || _isPlaying) ...[
                        const SizedBox(height: 16),
                        // Timeline indicator
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isRecording 
                                  ? 'Recording: ${_formatDuration(_recordingDuration)}'
                                  : 'Playing: ${_formatDuration(_playbackPosition)} / ${_formatDuration(_totalDuration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_isPlaying && _totalDuration.inSeconds > 0) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _playbackPosition.inMilliseconds / _totalDuration.inMilliseconds,
                                    backgroundColor: AppColors.borderColor,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (_recordedFilePath != null && !_isRecording) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isRecording ? null : _playRecording,
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
                            if (!_isPlaying) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _deleteRecording,
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete Recording',
                              ),
                            ],
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _isUploadingFiles ? null : _pickFiles,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isUploadingFiles ? AppColors.borderColor : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add,
                                color: _isUploadingFiles ? Colors.grey : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isUploadingFiles ? 'Uploading...' : 'Choose files...',
                                style: TextStyle(
                                  color: _isUploadingFiles ? Colors.grey : const Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedFiles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Column(
                          children: List.generate(_selectedFiles.length, (index) {
                            final file = _selectedFiles[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _getFileIcon(file.extension),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          file.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${(file.size / 1024).toStringAsFixed(2)} KB',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                    onPressed: () => _removeFile(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
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

  Future<void> _handleCreateTask() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? audioBase64;
        List<String> attachments = [];

        if (_recordedFilePath != null) {
          final bytes = await File(_recordedFilePath!).readAsBytes();
          audioBase64 = base64Encode(bytes);
        }

        if (_selectedFiles.isNotEmpty) {
          for (PlatformFile file in _selectedFiles) {
            final bytes = await file.bytes!.toList();
            attachments.add(base64Encode(bytes));
          }
        }

        // Create alarm settings map only if all required alarm fields are present
        Map<String, dynamic>? alarmSettings;
        if (_alarmStartDate != null && _alarmStartTime != null) {
          alarmSettings = {
            'start_date': _alarmStartDate!.toIso8601String().split('T')[0],
            'start_time': '${_alarmStartTime!.hour.toString().padLeft(2, '0')}:${_alarmStartTime!.minute.toString().padLeft(2, '0')}:00',
            'frequency': _alarmFrequency,
          };
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
          attachments: attachments,
          alarmSettings: alarmSettings,
        );

        if (response['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task created successfully')),
            );
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message'] ?? 'Failed to create task')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _requestInitialPermissions() async {
    try {
      print('🔐 [Permissions] Requesting initial permissions...');
      
      // Request all necessary permissions at start
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
      
      print('📱 [Permissions] Initial status:');
      statuses.forEach((permission, status) {
        print('  - ${permission.toString()}: $status');
      });
    } catch (e) {
      print('❌ [Permissions] Error requesting initial permissions: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _startRecording() async {
    try {
      print('\n🎤 [Recording] Starting recording process...');
      
      // Disable scrolling when recording starts
      setState(() {
        _canScroll = false;
      });

      // Check microphone permission before starting
      final micPermission = await Permission.microphone.status;
      print('📱 [Recording] Permission check:');
      print('  - Microphone: $micPermission');
      
      if (!micPermission.isGranted) {
        print('❌ [Recording] Microphone permission not granted, requesting...');
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          print('❌ [Recording] Microphone permission denied');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required for recording'),
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      // Create directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      print('📁 [Recording] App documents directory: ${appDir.path}');
      
      final dirPath = '${appDir.path}/recordings';
      print('📁 [Recording] Creating recordings directory at: $dirPath');
      
      try {
        await Directory(dirPath).create(recursive: true);
      } catch (e) {
        print('⚠️ [Recording] Directory creation warning (may already exist): $e');
      }
      
      final filePath = '$dirPath/audio_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      print('📝 [Recording] Will save recording to: $filePath');

      if (_isEmulatorTestMode) {
        // Create a test audio file for emulator testing
        print('🔧 [Recording] Running in emulator test mode');
        await _createTestAudioFile(filePath);
        setState(() {
          _isRecording = true;
          _recordedFilePath = filePath;
        });
        print('✅ [Recording] Test file created at: $filePath');
        return;
      }

      // Check if recorder is ready
      final isRecorderReady = await _audioRecorder.hasPermission();
      print('🎤 [Recording] Recorder ready status: $isRecorderReady');
      
      if (!isRecorderReady) {
        print('❌ [Recording] Recorder not ready');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to access microphone. Please check your permissions.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      print('⚙️ [Recording] Configuring recorder...');
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      print('✅ [Recording] Recording started successfully');

      setState(() {
        _isRecording = true;
        _recordedFilePath = filePath;
      });
      print('🔄 [Recording] State updated: isRecording=$_isRecording, filePath=$_recordedFilePath');

      // Start the recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });

    } catch (e) {
      print('❌ [Recording] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() {
        _canScroll = true;  // Re-enable scrolling if recording fails
      });
    }
  }

  Future<void> _createTestAudioFile(String filePath) async {
    try {
      // Create a simple test audio file (1 second of silence)
      final file = File(filePath);
      final List<int> headerBytes = [
        0x52, 0x49, 0x46, 0x46, // "RIFF"
        0x24, 0x00, 0x00, 0x00, // File size
        0x57, 0x41, 0x56, 0x45, // "WAVE"
        0x66, 0x6D, 0x74, 0x20, // "fmt "
        0x10, 0x00, 0x00, 0x00, // Format chunk size
        0x01, 0x00,             // Format tag (PCM)
        0x01, 0x00,             // Channels (mono)
        0x44, 0xAC, 0x00, 0x00, // Sample rate (44100 Hz)
        0x88, 0x58, 0x01, 0x00, // Bytes per second
        0x02, 0x00,             // Block align
        0x10, 0x00,             // Bits per sample
        0x64, 0x61, 0x74, 0x61, // "data"
        0x00, 0x00, 0x00, 0x00  // Data chunk size
      ];
      
      await file.writeAsBytes(headerBytes);
      print('✅ [Recording] Created test audio file with silence');
    } catch (e) {
      print('❌ [Recording] Error creating test file: $e');
      throw e;
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      print('⚠️ [Recording] Stop called but not currently recording');
      return;
    }

    try {
      print('\n🛑 [Recording] Stopping recording...');
      final path = await _audioRecorder.stop();
      print('✅ [Recording] Recording stopped. File saved at: $path');

      setState(() {
        _isRecording = false;
        _canScroll = true;  // Re-enable scrolling
        _recordingDuration = Duration.zero;
      });
      print('🔄 [Recording] State updated: isRecording=$_isRecording');

      // Verify file exists and check its size
      final file = File(path ?? '');
      if (await file.exists()) {
        final size = await file.length();
        print('📁 [Recording] File verification:');
        print('  - Path: ${file.path}');
        print('  - Size: $size bytes');
        print('  - Exists: true');
        
        // Read first few bytes to verify it's not empty
        if (size > 0) {
          final bytes = await file.openRead(0, min(size, 16)).toList();
          print('  - First few bytes: $bytes');
          print('✅ [Recording] File verification complete - file is valid');
        }
      } else {
        print('❌ [Recording] Warning: Recording file not found at: ${file.path}');
      }
    } catch (e) {
      print('❌ [Recording] Error in _stopRecording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
      setState(() {
        _canScroll = true;  // Re-enable scrolling on error
      });
    }
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath == null || _isRecording) return;
    
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        _playbackTimer?.cancel();
        setState(() {
          _isPlaying = false;
          _playbackPosition = Duration.zero;
          _canScroll = true;
        });
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
        setState(() {
          _isPlaying = true;
          _canScroll = false;
        });

        // Listen for playback completion
        _audioPlayer.onPlayerComplete.listen((event) {
          _playbackTimer?.cancel();
          setState(() {
            _isPlaying = false;
            _playbackPosition = Duration.zero;
            _canScroll = true;
          });
        });
      }
    } catch (e) {
      print('❌ [Playback] Error: $e');
      _playbackTimer?.cancel();
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
        _canScroll = true;
      });
    }
  }

  Future<void> _deleteRecording() async {
    if (_recordedFilePath == null) {
      print('⚠️ [Delete] No recording to delete');
      return;
    }
    
    try {
      print('\n🗑️ [Delete] Attempting to delete recording at: $_recordedFilePath');
      final file = File(_recordedFilePath!);
      if (await file.exists()) {
        await file.delete();
        print('✅ [Delete] Recording deleted successfully');
      } else {
        print('⚠️ [Delete] File does not exist');
      }
      setState(() {
        _recordedFilePath = null;
      });
      print('🔄 [Delete] State updated: recordedFilePath=null');
    } catch (e) {
      print('❌ [Delete] Error: $e');
    }
  }
} 