import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/custom_text_field.dart';
import '../models/task.dart';
import '../models/attachment.dart';
import '../models/voice_note.dart';
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
import '../services/socket_service.dart';
import 'package:open_file/open_file.dart';

class CreateTaskScreen extends StatefulWidget {
  final bool isEditMode;
  final String? taskId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialAssignee;
  final String? initialPriority;
  final DateTime? initialDueDate;
  final String? initialStatus;

  const CreateTaskScreen({
    Key? key,
    this.isEditMode = false,
    this.taskId,
    this.initialTitle,
    this.initialDescription,
    this.initialAssignee,
    this.initialPriority,
    this.initialDueDate,
    this.initialStatus,
  }) : super(key: key);

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AudioRecorder _audioRecorder;
  final _socketService = SocketService();
  
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
  List<VoiceNote> _voiceNotes = [];
  List<Attachment> _existingAttachments = [];

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

  bool _isLoadingVoiceNotes = true;
  bool _isLoadingAttachments = true;
  String? _currentlyPlayingNoteId;

  @override
  void initState() {
    super.initState();
    print('🎤 [Init] Initializing AudioRecorder...');
    _audioRecorder = AudioRecorder();
    _checkMicrophoneStatus();
    _getCurrentUser();
    _setupAudioPlayer();
    _requestInitialPermissions();
    _initializeData();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _socketService.removeTaskNotificationListener(_handleTaskNotification);
    _socketService.removeDashboardUpdateListener(_handleDashboardUpdate);
    super.dispose();
  }

  void _setupSocketListeners() {
    _socketService.listenToTaskNotifications(_handleTaskNotification);
    _socketService.listenToDashboardUpdates(_handleDashboardUpdate);
  }

  void _handleTaskNotification(dynamic data) {
    // Handle notifications while screen is active
    if (mounted && ModalRoute.of(context)!.isCurrent) {
      // Check if the current user is the creator/updater
      final bool isCreator = data['task']?['assigned_by'] == _currentUsername;
      final bool isUpdater = data['task']?['updated_by'] == _currentUsername;
      
      // Only show notification if user is not the creator/updater
      if (!isCreator && !isUpdater) {
        if (data['type'] == 'task_created' || data['type'] == 'task_updated') {
          // Show a temporary success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['type'] == 'task_created' 
                    ? 'New task has been created'
                    : 'Task has been updated'
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  void _handleDashboardUpdate(dynamic data) {
    // Handle dashboard updates while screen is active
    if (mounted && ModalRoute.of(context)!.isCurrent) {
      // Check if the current user is the creator/updater
      final bool isCreator = data['assigned_by'] == _currentUsername;
      final bool isUpdater = data['updated_by'] == _currentUsername;
      
      // Only process updates if user is not the creator/updater
      if (!isCreator && !isUpdater) {
        // Handle any necessary UI updates
      }
    }
  }

  Future<void> _initializeData() async {
    if (widget.isEditMode) {
      _titleController.text = widget.initialTitle ?? '';
      _descriptionController.text = widget.initialDescription ?? '';
      _selectedAssignee = widget.initialAssignee;
      _priority = widget.initialPriority ?? 'Low';
      _dueDate = widget.initialDueDate;
      _status = _parseStatus(widget.initialStatus ?? 'pending');
      
      // Fetch existing voice notes and attachments
      await _loadTaskVoiceNotes();
      await _loadTaskAttachments();
    }
  }

  Future<void> _loadTaskVoiceNotes() async {
    try {
      setState(() {
        _isLoadingVoiceNotes = true;
      });

      final voiceNotes = await _apiService.getTaskVoiceNotes(widget.taskId!);
      setState(() {
        _voiceNotes = voiceNotes;
        _isLoadingVoiceNotes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingVoiceNotes = false;
      });
      _showErrorSnackBar('Failed to load voice notes');
    }
  }

  Future<void> _loadTaskAttachments() async {
    try {
      setState(() {
        _isLoadingAttachments = true;
      });

      final attachments = await _apiService.getTaskAttachments(widget.taskId!);
      setState(() {
        _existingAttachments = attachments;
        _isLoadingAttachments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAttachments = false;
      });
      _showErrorSnackBar('Failed to load attachments');
    }
  }

  TaskStatus _parseStatus(String status) {
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

  Future<bool> _requestStoragePermission() async {
    print('📱 [Permissions] Checking storage permissions...');
    
    try {
      // For Android 13 and above
      if (await Permission.photos.request().isGranted &&
          await Permission.videos.request().isGranted &&
          await Permission.audio.request().isGranted) {
        print('✅ [Permissions] Media permissions granted');
        return true;
      }
      
      // For Android 12 and below
      final status = await Permission.storage.request();
      if (status.isGranted) {
        print('✅ [Permissions] Storage permission granted');
        return true;
      }

      // If permissions are denied, show rationale
      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text(
                'Storage Permission Required',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Storage permission is required to pick files. Please enable it in app settings.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.pop(context);
                  },
                  child: const Text('Open Settings', style: TextStyle(color: Color(0xFF7DF9FF))),
                ),
              ],
            ),
          );
        }
        return false;
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
    } catch (e) {
      print('❌ [Permissions] Error requesting storage permission: $e');
      return false;
    }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEditMode ? 'Edit Task' : 'Create Task',
          style: const TextStyle(
            color: Color(0xFF7DF9FF),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7DF9FF)),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      AbsorbPointer(
                        absorbing: widget.isEditMode,
                        child: Opacity(
                          opacity: widget.isEditMode ? 0.7 : 1.0,
                          child: CustomTextField(
                            controller: _titleController,
                            label: 'Title',
                            hint: 'Enter task title',
                            enabled: !widget.isEditMode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      AbsorbPointer(
                        absorbing: widget.isEditMode,
                        child: Opacity(
                          opacity: widget.isEditMode ? 0.7 : 1.0,
                          child: CustomTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'Enter task description',
                            maxLines: 4,
                            enabled: !widget.isEditMode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Assignee
                      AbsorbPointer(
                        absorbing: widget.isEditMode,
                        child: Opacity(
                          opacity: widget.isEditMode ? 0.7 : 1.0,
                          child: RoleDropdown(
                            label: 'Assignee',
                            hint: 'Select assignee',
                            items: _users,
                            value: _selectedAssignee,
                            onChanged: widget.isEditMode ? null : (String? value) {
                              setState(() {
                                _selectedAssignee = value;
                              });
                            },
                          ),
                        ),
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
                                      initialDate: _dueDate ?? DateTime.now(),
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
                      // Existing voice notes in edit mode
                      if (widget.isEditMode) _buildExistingVoiceNotes(),
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
                      // Existing attachments in edit mode
                      if (widget.isEditMode) _buildExistingAttachments(),
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
                              child: Text(
                                widget.isEditMode ? 'Save' : 'Create Task',
                                style: const TextStyle(
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
    // Validate form first
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    if (_selectedAssignee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an assignee')),
      );
      return;
    }

    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? audioNote;
      List<Map<String, dynamic>> attachments = [];

      // Handle audio recording
      if (_recordedFilePath != null) {
        print('📝 [Upload] Processing audio file: $_recordedFilePath');
        final File audioFile = File(_recordedFilePath!);
        if (await audioFile.exists()) {
          final bytes = await audioFile.readAsBytes();
          if (bytes.isEmpty) {
            print('❌ [Upload] Audio file is empty');
            throw Exception('Audio file is empty');
          }
          
          print('📝 [Upload] Audio file size: ${bytes.length} bytes');
          final String base64Audio = base64Encode(bytes);
          
          // Get audio duration if available
          int duration = 0;
          try {
            final audioPlayer = AudioPlayer();
            await audioPlayer.setSourceDeviceFile(_recordedFilePath!);
            final audioDuration = await audioPlayer.getDuration();
            duration = audioDuration?.inMilliseconds ?? 0;
            await audioPlayer.dispose();
          } catch (e) {
            print('⚠️ [Upload] Could not get audio duration: $e');
          }

          audioNote = base64Audio;
          print('✅ [Upload] Audio processed successfully');
          print('  - Duration: ${duration}ms');
          print('  - Base64 length: ${base64Audio.length}');
        } else {
          print('❌ [Upload] Audio file not found: $_recordedFilePath');
        }
      }

      // Handle file attachments
      if (_selectedFiles.isNotEmpty) {
        print('📝 [Upload] Processing ${_selectedFiles.length} attachments');
        for (PlatformFile file in _selectedFiles) {
          try {
            if (file.bytes == null || file.bytes!.isEmpty) {
              print('⚠️ [Upload] Skipping empty file: ${file.name}');
              continue;
            }

            print('📝 [Upload] Processing file: ${file.name}');
            print('  - Size: ${file.size} bytes');
            print('  - Type: ${file.extension}');

            final String base64File = base64Encode(file.bytes!);
            
            // Create a structured attachment object
            final Map<String, dynamic> attachmentData = {
              'file_name': file.name,
              'file_type': file.extension?.toLowerCase() ?? 'unknown',
              'file_size': file.size,
              'file_data': base64File
            };
            
            // Add to attachments list
            attachments.add(attachmentData);
            print('✅ [Upload] File processed successfully: ${file.name}');
          } catch (e) {
            print('❌ [Upload] Error processing file ${file.name}: $e');
            // Continue with other files if one fails
            continue;
          }
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

      // Print request data for debugging
      print('📤 [Upload] Sending request with data:');
      final requestData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'assigned_to': _selectedAssignee,
        'assigned_by': _currentUsername,
        'deadline': _dueDate!.toIso8601String(),
        'priority': _priority.toLowerCase(),
        'status': _getStatusString(_status),
        if (audioNote != null) 'audio_note': {
          'audio_data': audioNote,
          'file_name': 'voice_note_${DateTime.now().millisecondsSinceEpoch}.wav',
          'duration': _recordingDuration.inMilliseconds
        },
        if (attachments.isNotEmpty) 'attachments': attachments,
        if (alarmSettings != null) 'alarm_settings': alarmSettings,
      };
      
      // Print request summary (without the actual file data)
      print('📤 [Upload] Request summary:');
      print('  - Title: ${requestData['title']}');
      print('  - Has audio: ${audioNote != null}');
      print('  - Attachments count: ${attachments.length}');
      print('  - Has alarm: ${alarmSettings != null}');

      final response = widget.isEditMode
          ? await _apiService.updateTask(
              taskId: widget.taskId!,
              priority: _priority.toLowerCase(),
              status: _getStatusString(_status),
              deadline: _dueDate!.toIso8601String(),
              audioNote: audioNote,
              attachments: attachments.isNotEmpty ? attachments : null,
              alarmSettings: alarmSettings,
              updatedBy: _currentUsername ?? '',
            )
          : await _apiService.createTask(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              assignedTo: _selectedAssignee!,
              assignedBy: _currentUsername ?? '',
              deadline: _dueDate!.toIso8601String(),
              priority: _priority.toLowerCase(),
              status: _getStatusString(_status),
              audioNote: audioNote,
              attachments: attachments.isNotEmpty ? attachments : null,
              alarmSettings: alarmSettings,
            );

      if (response['success'] == true) {
        if (mounted) {
          // Show success dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF7DF9FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFF0F172A),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.isEditMode ? 'Task Updated Successfully!' : 'Task Created Successfully!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isEditMode
                            ? 'Task has been updated successfully.'
                            : 'Task "${_titleController.text}" has been created and assigned to $_selectedAssignee.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.pop(context, true); // Return to previous screen
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF7DF9FF),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to save task')),
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

  String _getStatusString(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'pending';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.snoozed:
        return 'snoozed';
      default:
        return 'pending';
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
      
      setState(() {
        _canScroll = false;
      });

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

      final appDir = await getApplicationDocumentsDirectory();
      print('📁 [Recording] App documents directory: ${appDir.path}');
      
      final dirPath = '${appDir.path}/recordings';
      print('📁 [Recording] Creating recordings directory at: $dirPath');
      
      try {
        await Directory(dirPath).create(recursive: true);
      } catch (e) {
        print('⚠️ [Recording] Directory creation warning (may already exist): $e');
      }
      
      final filePath = '$dirPath/audio_note_${DateTime.now().millisecondsSinceEpoch}.wav';
      print('📝 [Recording] Will save recording to: $filePath');

      if (_isEmulatorTestMode) {
        print('🔧 [Recording] Running in emulator test mode');
        await _createTestAudioFile(filePath);
        setState(() {
          _isRecording = true;
          _recordedFilePath = filePath;
        });
        print('✅ [Recording] Test file created at: $filePath');
        return;
      }

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
          encoder: AudioEncoder.wav,  // Changed to WAV format
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
        _canScroll = true;
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

  // Add playback methods
  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
        _canScroll = true;
      });
      _playbackTimer?.cancel();
    } catch (e) {
      print('❌ [Playback] Error stopping playback: $e');
    }
  }

  Future<String?> _getVoiceNoteFilePath(VoiceNote voiceNote) async {
    if (voiceNote.filePath != null && await File(voiceNote.filePath!).exists()) {
      return voiceNote.filePath;
    }
    
    if (voiceNote.audioData != null) {
      return await _apiService.downloadVoiceNote(voiceNote);
    }
    
    return null;
  }

  Future<String?> _getAttachmentFilePath(Attachment attachment) async {
    if (attachment.filePath != null && File(attachment.filePath!).existsSync()) {
      return attachment.filePath;
    }
    
    try {
      final filePath = await _apiService.downloadAttachment(attachment.id);
      return filePath;
    } catch (e) {
      _showErrorSnackBar('Failed to download attachment');
      return null;
    }
  }

  Future<void> _playVoiceNote(VoiceNote voiceNote) async {
    try {
      final filePath = await _getVoiceNoteFilePath(voiceNote);
      if (filePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to play voice note - no audio data available')),
        );
        return;
      }

      final playerState = await _audioPlayer.state;
      if (playerState == PlayerState.playing) {
        await _audioPlayer.stop();
      }

      await _audioPlayer.setSource(DeviceFileSource(filePath));
      await _audioPlayer.resume();
    } catch (e) {
      print('❌ [Playback] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to play voice note')),
      );
    }
  }

  Future<void> _openAttachment(Attachment attachment) async {
    try {
      final filePath = await _getAttachmentFilePath(attachment);
      if (filePath == null) {
        _showErrorSnackBar('Attachment file not available');
        return;
      }

      await OpenFile.open(filePath);
    } catch (e) {
      _showErrorSnackBar('Failed to open attachment');
    }
  }

  // Update the existing voice notes list builder
  Widget _buildExistingVoiceNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_voiceNotes.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Existing Voice Notes',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _voiceNotes.length,
            itemBuilder: (context, index) {
              final voiceNote = _voiceNotes[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: StreamBuilder<PlayerState>(
                    stream: _audioPlayer.onPlayerStateChanged,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data == PlayerState.playing;
                      return IconButton(
                        icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                        onPressed: () => _playVoiceNote(voiceNote),
                      );
                    }
                  ),
                  title: Text('Voice Note ${index + 1}'),
                  subtitle: Text('Created by: ${voiceNote.createdBy ?? 'Unknown'}'),
                  trailing: Text(
                    '${(voiceNote.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // Update the existing attachments list builder
  Widget _buildExistingAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_existingAttachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Existing Attachments',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _existingAttachments.length,
            itemBuilder: (context, index) {
              final attachment = _existingAttachments[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      _getFileIcon(attachment.fileType),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                '${(attachment.fileSize / 1024).toStringAsFixed(2)} KB',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              if (attachment.createdBy != null) ...[
                                const Text(
                                  ' • ',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'By ${attachment.createdBy}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Download button
                    IconButton(
                      icon: const Icon(Icons.download, color: Color(0xFF7DF9FF)),
                      onPressed: () => _openAttachment(attachment),
                      tooltip: 'Download',
                    ),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _existingAttachments.removeAt(index);
                          _selectedFiles.removeAt(index);
                        });
                      },
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
} 