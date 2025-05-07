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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

class CreateTaskScreen extends StatefulWidget {
  final bool isEditMode;
  final String? taskId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialAssignee;
  final String? initialAssigner;
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
    this.initialAssigner,
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
  final _socketService = SocketService.instance;

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

  final bool _isEmulatorTestMode = false;

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

  List<Map<String, dynamic>> _notifications = [];
  bool _showNotifications = false;

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
    _initializeAudioPlayer();
    _fetchUsers();
    _loadNotifications();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _disposeAudioPlayer();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUsername = prefs.getString('username');
    if (_currentUsername != null) {
      _socketService.connect(_currentUsername!);
      _setupSocketListeners();
    }
  }

  void _setupSocketListeners() {
    _socketService.listenToTaskNotifications(_handleTaskNotification);
    _socketService.listenToDashboardUpdates(_handleDashboardUpdate);
  }

  void _handleTaskNotification(dynamic data) {
    if (mounted && ModalRoute.of(context)!.isCurrent) {
      final bool isCreator = data['task']?['assigned_by'] == _currentUsername;
      final bool isUpdater = data['task']?['updated_by'] == _currentUsername;

      if (!isCreator && !isUpdater) {
        if (data['type'] == 'task_created' || data['type'] == 'task_updated') {
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
    if (mounted && ModalRoute.of(context)!.isCurrent) {
      final bool isCreator = data['assigned_by'] == _currentUsername;
      final bool isUpdater = data['updated_by'] == _currentUsername;

      if (isCreator || isUpdater) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCreator
                ? 'Task created successfully!'
                : 'Task updated successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
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
      
      // Properly initialize status from initialStatus
      if (widget.initialStatus != null) {
        print('📝 [Task] Initializing status from: ${widget.initialStatus}');
        switch (widget.initialStatus!.toLowerCase()) {
          case 'pending':
            _status = TaskStatus.pending;
            break;
          case 'in_progress':
            _status = TaskStatus.inProgress;
            break;
          case 'completed':
            _status = TaskStatus.completed;
            break;
          case 'snoozed':
            _status = TaskStatus.snoozed;
            break;
          default:
            _status = TaskStatus.pending;
        }
        print('📝 [Task] Status initialized to: ${_status.toString().split('.').last}');
      } else {
        _status = TaskStatus.pending;
      }
      
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
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _playbackPosition = position;
      });
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
  }

  Future<void> _checkMicrophoneStatus() async {
    try {
      print('\n🎤 [Microphone] Checking microphone status...');
      final micPermission = await Permission.microphone.status;
      print('🎤 [Microphone] Permission status: $micPermission');
      final hasRecordingPermission = await _audioRecorder.hasPermission();
      print('🎤 [Microphone] Recording permission: $hasRecordingPermission');
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

  Future<void> _fetchUsers() async {
    try {
      setState(() {
        _isLoadingUsers = true;
      });
      final users = await _apiService.getUsers();
      if (mounted) {
        setState(() {
          _users = users.where((user) => user != _currentUsername).toList();
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('❌ [Users] Error fetching users: $e');
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // Request storage permission
        final storage = await Permission.storage.request();
        if (storage.isGranted) {
          print('✅ [Permissions] Storage permission granted');
          return true;
        }

        // If storage permission is denied, try media permissions
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        
        if (photos.isGranted || videos.isGranted) {
          print('✅ [Permissions] Media permissions granted');
          return true;
        }

        // If all permissions are denied, show settings dialog
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text(
                'Storage Permission Required',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Storage permission is required to pick files. Would you like to open settings?',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings', style: TextStyle(color: Color(0xFF7DF9FF))),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await openAppSettings();
          }
        }
      } else {
        // For iOS and other platforms
        final storage = await Permission.storage.request();
        if (storage.isGranted) {
          print('✅ [Permissions] Storage permission granted');
          return true;
        }
      }

      print('❌ [Permissions] Storage permissions denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to pick files'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    } catch (e) {
      print('❌ [Permissions] Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> _pickFiles() async {
    try {
      if (!await _requestStoragePermission()) {
        print('❌ [Files] Storage permission not granted');
        return;
      }
      
      setState(() {
        _isUploadingFiles = true;
      });
      
      print('📁 [Files] Opening file picker...');
      
      // Basic file picker configuration without event channel
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        // Remove withReadStream and onFileLoading to avoid event channel issues
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        print('📁 [Files] Files selected successfully');
        final validFiles = result.files.where((file) => 
          file.path != null && 
          file.name.isNotEmpty && 
          file.size > 0
        ).toList();

        if (validFiles.isEmpty) {
          print('❌ [Files] No valid files selected');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid files selected'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _selectedFiles = validFiles;
        });
        
        for (final file in validFiles) {
          print('📎 [Files] Selected file:');
          print('  - Name: ${file.name}');
          print('  - Size: ${(file.size / 1024).toStringAsFixed(2)} KB');
          print('  - Extension: ${file.extension ?? "unknown"}');
          print('  - Path: ${file.path ?? "unknown"}');
        }
      } else {
        print('📁 [Files] No files selected or picker was canceled');
      }
    } catch (e, stackTrace) {
      print('❌ [Files] Error picking files: $e');
      print('❌ [Files] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFiles = false;
        });
      }
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
          onPressed: () {
            _stopPlayback();
            Navigator.pop(context);
          },
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
                _buildNotificationPanel(),
                AbsorbPointer(
                  absorbing: widget.isEditMode,
                  child: Opacity(
                    opacity: widget.isEditMode ? 0.7 : 1.0,
                    child: CustomTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'Enter task title',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isEditMode,
                  child: Opacity(
                    opacity: widget.isEditMode ? 0.7 : 1.0,
                    child: CustomTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Enter task description',
                      maxLines: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isEditMode,
                  child: Opacity(
                    opacity: widget.isEditMode ? 0.7 : 1.0,
                    child: RoleDropdown(
                      label: 'Assignee',
                      hint: _isLoadingUsers ? 'Loading users...' : 'Select assignee',
                      items: _users,
                      value: _selectedAssignee,
                      onChanged: widget.isEditMode ? null : (String? value) {
                        setState(() {
                          _selectedAssignee = value;
                        });
                      },
                      isLoading: _isLoadingUsers,
                      validator: (value) {
                        if (!widget.isEditMode && (value == null || value.isEmpty)) {
                          return 'Please select an assignee';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
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
                            return 'Please select a priority';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
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
                if (widget.isEditMode) ...[
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
                ],
                const Text(
                  'Alarm Settings',
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
                if (widget.isEditMode && _voiceNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Audio Notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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
                      final isPlaying = _currentlyPlayingNoteId == voiceNote.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1526),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: const Color(0xFF7DF9FF),
                              ),
                              onPressed: () async {
                                if (isPlaying) {
                                  await _stopPlayback();
                                  setState(() {
                                    _currentlyPlayingNoteId = null;
                                  });
                                } else {
                                  setState(() {
                                    _currentlyPlayingNoteId = voiceNote.id;
                                  });
                                  await _playVoiceNote(voiceNote);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Voice Note ${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'By: ${voiceNote.createdBy}',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isPlaying && _totalDuration.inSeconds > 0) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _playbackPosition.inMilliseconds / _totalDuration.inMilliseconds,
                                        backgroundColor: const Color(0xFF0D1526),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7DF9FF)),
                                        minHeight: 2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
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
                if (widget.isEditMode) _buildExistingAttachments(),
                const SizedBox(height: 16),
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
          print('📝 [Task] Changing status from ${_status.toString().split('.').last} to ${status.toString().split('.').last}');
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
        await _stopPlayback();
        Map<String, dynamic>? audioNote;
        
        // Validate and process audio recording
        if (_recordedFilePath != null) {
          print('🎤 [Task] Processing audio recording...');
          final audioFile = File(_recordedFilePath!);
          if (await audioFile.exists()) {
            final fileSize = await audioFile.length();
            print('📊 [Task] Audio file size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
            
            if (fileSize > 0) {
              final audioBytes = await audioFile.readAsBytes();
              final base64Audio = base64Encode(audioBytes);
              final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
              audioNote = {
                'filename': filename,
                'duration': _recordingDuration.inSeconds,
                'audio_data': base64Audio,
              };
              print('✅ [Task] Audio note prepared successfully');
            } else {
              print('⚠️ [Task] Audio file is empty');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audio recording is empty')),
              );
            }
          } else {
            print('❌ [Task] Audio file not found at: $_recordedFilePath');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audio recording file not found')),
            );
          }
        }

        // Validate and process attachments
        List<Map<String, dynamic>> attachmentData = [];
        if (_selectedFiles.isNotEmpty) {
          print('📎 [Task] Processing ${_selectedFiles.length} attachments...');
          
          for (final file in _selectedFiles) {
            if (file.path == null) {
              print('❌ [Task] File path is null for: ${file.name}');
              continue;
            }
            
            final attachmentFile = File(file.path!);
            if (await attachmentFile.exists()) {
              final fileSize = await attachmentFile.length();
              print('📊 [Task] Attachment: ${file.name} (${(fileSize / 1024).toStringAsFixed(2)} KB)');
              
              if (fileSize > 0) {
                final fileBytes = await attachmentFile.readAsBytes();
                final base64File = base64Encode(fileBytes);
                final fileType = file.extension ?? '';
                
                attachmentData.add({
                  'file_name': file.name,
                  'file_type': fileType,
                  'file_data': base64File,
                });
                print('✅ [Task] Attachment prepared: ${file.name}');
              } else {
                print('⚠️ [Task] Empty file: ${file.name}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('File is empty: ${file.name}')),
                );
              }
            } else {
              print('❌ [Task] File not found: ${file.path}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('File not found: ${file.name}')),
              );
            }
          }
          
          if (attachmentData.isEmpty) {
            print('⚠️ [Task] No valid attachments to upload');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No valid attachments to upload')),
            );
          } else {
            print('✅ [Task] ${attachmentData.length} valid attachments ready for upload');
          }
        }

        // Process alarm settings
        Map<String, dynamic>? alarmSettings;
        if (_alarmStartDate != null && _alarmStartTime != null) {
          final alarmDateTime = DateTime(
            _alarmStartDate!.year,
            _alarmStartDate!.month,
            _alarmStartDate!.day,
            _alarmStartTime!.hour,
            _alarmStartTime!.minute,
          );
          alarmSettings = {
            'start_date': alarmDateTime.toIso8601String().split('T')[0],
            'start_time': alarmDateTime.toIso8601String().split('T')[1].substring(0, 8),
            'frequency': _alarmFrequency,
          };
        }

        String response;
        if (widget.isEditMode) {
          if (_selectedAssignee == null || _selectedAssignee!.isEmpty) {
            throw Exception('Assignee is missing');
          }
          print('📝 [Task] Updating existing task...');
          print('📝 [Task] Priority: ${_priority.toLowerCase()}');
          print('📝 [Task] Status: ${_getStatusString(_status)}');
          response = await _apiService.updateTask(
            taskId: widget.taskId!,
            title: _titleController.text,
            description: _descriptionController.text,
            assignedTo: _selectedAssignee!,
            assignedBy: widget.initialAssigner.toString(),
            deadline: _dueDate ?? DateTime.now(),
            priority: _priority.toLowerCase(),
            status: _getStatusString(_status),
            audioNote: audioNote,
            attachments: attachmentData,
            alarmSettings: alarmSettings,
          );
        } else {
          if (_currentUsername == null || _currentUsername!.isEmpty) {
            throw Exception('Current user is not logged in');
          }
          if (_selectedAssignee == null || _selectedAssignee!.isEmpty) {
            throw Exception('Assignee is missing');
          }
          print('📝 [Task] Creating new task...');
          print('📝 [Task] Priority: ${_priority.toLowerCase()}');
          response = await _apiService.createTask(
            title: _titleController.text,
            description: _descriptionController.text,
            assignedTo: _selectedAssignee!,
            assignedBy: _currentUsername!,
            deadline: _dueDate ?? DateTime.now(),
            priority: _priority.toLowerCase(),
            status: 'pending',
            audioNote: audioNote,
            attachments: attachmentData,
            alarmSettings: alarmSettings,
          );
        }

        print('✅ [Task] Task ${widget.isEditMode ? "updated" : "created"} successfully');
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode ? 'Task updated successfully' : 'Task created successfully',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(
                color: Color(0xFF7DF9FF),
                width: 1,
              ),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        print('❌ [Task] Error ${widget.isEditMode ? "updating" : "creating"} task: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${widget.isEditMode ? "updating" : "creating"} task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _selectedAssignee = null;
    _dueDate = null;
    _priority = 'Low';
    _status = TaskStatus.pending;
    _isRecording = false;
    _isPlaying = false;
    _recordedFilePath = null;
    _recordingDuration = Duration.zero;
    _selectedFiles.clear();
    _alarmStartDate = null;
    _alarmStartTime = null;
    _alarmFrequency = '30 minutes';
    setState(() {});
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
          encoder: AudioEncoder.wav,
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
      final file = File(filePath);
      final List<int> headerBytes = [
        0x52, 0x49, 0x46, 0x46,
        0x24, 0x00, 0x00, 0x00,
        0x57, 0x41, 0x56, 0x45,
        0x66, 0x6D, 0x74, 0x20,
        0x10, 0x00, 0x00, 0x00,
        0x01, 0x00,
        0x01, 0x00,
        0x44, 0xAC, 0x00, 0x00,
        0x88, 0x58, 0x01, 0x00,
        0x02, 0x00,
        0x10, 0x00,
        0x64, 0x61, 0x74, 0x61,
        0x00, 0x00, 0x00, 0x00
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
        _canScroll = true;
        _recordingDuration = Duration.zero;
      });
      print('🔄 [Recording] State updated: isRecording=$_isRecording');
      final file = File(path ?? '');
      if (await file.exists()) {
        final size = await file.length();
        print('📁 [Recording] File verification:');
        print('  - Path: ${file.path}');
        print('  - Size: $size bytes');
        print('  - Exists: true');
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
        _canScroll = true;
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

  Future<void> _playVoiceNote(VoiceNote voiceNote) async {
    try {
      print('🎵 [VoiceNote] Attempting to play voice note: ${voiceNote.id}');
      print('🎵 [VoiceNote] Task ID: ${widget.taskId}');
      print('🎵 [VoiceNote] Has audio data: ${voiceNote.audioData != null}');
      print('🎵 [VoiceNote] Has file path: ${voiceNote.filePath != null}');

      if (voiceNote.id == null) {
        print('❌ [VoiceNote] Voice note ID is null');
        throw Exception('Invalid voice note: ID is null');
      }

      if (widget.taskId == null) {
        print('❌ [VoiceNote] Task ID is null');
        throw Exception('Invalid task: Task ID is null');
      }

      // Stop any current playback
      if (_audioPlayer.state == PlayerState.playing) {
        print('🎵 [VoiceNote] Stopping current playback');
        await _audioPlayer.stop();
      }

      String? filePath;
      
      // First check if we have audio data
      if (voiceNote.audioData != null && voiceNote.audioData!.isNotEmpty) {
        print('🎵 [VoiceNote] Creating file from audio data');
        final tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}/voice_note_${voiceNote.id}.wav';
        final file = File(filePath);
        await file.writeAsBytes(base64Decode(voiceNote.audioData!));
        print('✅ [VoiceNote] Created file from audio data: $filePath');
      }
      // Then check if we have a valid file path
      else if (voiceNote.filePath != null && await File(voiceNote.filePath!).exists()) {
        print('🎵 [VoiceNote] Using existing file path: ${voiceNote.filePath}');
        filePath = voiceNote.filePath;
      }
      // Finally, try to download from API
      else {
        print('🎵 [VoiceNote] Attempting to download from API...');
        final apiService = ApiService();
        filePath = await apiService.downloadVoiceNote(voiceNote);
        print('🎵 [VoiceNote] Download result: $filePath');
      }

      if (filePath == null) {
        print('❌ [VoiceNote] No valid source found for voice note');
        throw Exception('No valid audio source found for voice note');
      }

      // Verify file exists and has content
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ [VoiceNote] File does not exist at path: $filePath');
        throw Exception('Voice note file not found');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        print('❌ [VoiceNote] File is empty at path: $filePath');
        throw Exception('Voice note file is empty');
      }

      print('🎵 [VoiceNote] Playing from file: $filePath (size: $fileSize bytes)');
      
      // Configure player
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      await _audioPlayer.setVolume(1.0);
      
      // Play the audio
      await _audioPlayer.play(DeviceFileSource(filePath));
      print('✅ [VoiceNote] Playback started successfully');

    } catch (e) {
      print('❌ [VoiceNote] Error playing voice note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play voice note: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String?> _getVoiceNoteFilePath(VoiceNote voiceNote) async {
    try {
      // First check if we have audio data
      if (voiceNote.audioData != null && voiceNote.audioData!.isNotEmpty) {
        print('🎵 [VoiceNote] Creating file from audio data');
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/voice_note_${voiceNote.id}.wav';
        final file = File(filePath);
        await file.writeAsBytes(base64Decode(voiceNote.audioData!));
        print('✅ [VoiceNote] Created file from audio data: $filePath');
        return filePath;
      }
      
      // Then check if we have a valid file path
      if (voiceNote.filePath != null && await File(voiceNote.filePath!).exists()) {
        print('🎵 [VoiceNote] Using existing file path: ${voiceNote.filePath}');
        return voiceNote.filePath;
      }
      
      // Finally, try to download from API
      print('🎵 [VoiceNote] Attempting to download from API...');
      final apiService = ApiService();
      final filePath = await apiService.downloadVoiceNote(voiceNote);
      print('🎵 [VoiceNote] Download result: $filePath');
      return filePath;
    } catch (e) {
      print('❌ [VoiceNote] Error getting voice note file path: $e');
      return null;
    }
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
                    IconButton(
                      icon: const Icon(Icons.download, color: Color(0xFF7DF9FF)),
                      onPressed: () => _openAttachment(attachment),
                      tooltip: 'Download',
                    ),
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

  Future<void> _initializeAudioPlayer() async {
    try {
      print('🎵 [Audio] Initializing audio player...');
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.mixWithOthers,
          ],
        ),
      ));
      _positionSubscription?.cancel();
      _positionSubscription = _audioPlayer.onPositionChanged.listen(
            (position) {
          if (mounted) {
            setState(() {
              _playbackPosition = position;
            });
          }
        },
        onError: (error) {
          print('❌ [Audio] Position listener error: $error');
        },
      );
      _durationSubscription?.cancel();
      _durationSubscription = _audioPlayer.onDurationChanged.listen(
            (duration) {
          if (mounted) {
            setState(() {
              _totalDuration = duration;
            });
          }
        },
        onError: (error) {
          print('❌ [Audio] Duration listener error: $error');
        },
      );
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _playbackPosition = Duration.zero;
            _currentlyPlayingNoteId = null;
          });
        }
      });
      _audioPlayer.onPlayerStateChanged.listen(
            (state) {
          if (mounted) {
            setState(() {
              _isPlaying = state == PlayerState.playing;
            });
          }
          print('🎵 [Audio] Player state changed: $state');
        },
        onError: (error) {
          print('❌ [Audio] State listener error: $error');
        },
      );
      print('✅ [Audio] Audio player initialized successfully');
    } catch (e) {
      print('❌ [Audio] Error initializing audio player: $e');
      _showErrorSnackBar('Failed to initialize audio player');
    }
  }

  void _disposeAudioPlayer() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await _apiService.getNotifications();
      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      print('❌ Error loading notifications: $e');
    }
  }

  Widget _buildNotificationPanel() {
    if (!_showNotifications) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7DF9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showNotifications = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No notifications',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1526),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'] ?? 'Notification',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'] ?? '',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      if (notification['timestamp'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatNotificationTime(notification['timestamp']),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatNotificationTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timestamp;
    }
  }
}