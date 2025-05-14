import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';

class AlarmScreen extends StatefulWidget {
  final String? taskId;
  final String? taskTitle;
  final String? alarmId;
  final String? assigneeName;
  final String? dueDate;

  const AlarmScreen({
    Key? key,
    this.taskId,
    this.taskTitle,
    this.alarmId,
    this.assigneeName,
    this.dueDate,
  }) : super(key: key);

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final AudioService _audioService = AudioService();
  final AudioPlayer _directPlayer = AudioPlayer(); // Direct player for testing
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isAlarmActive = false;
  Map<String, dynamic>? _activeAlarm;
  Timer? _vibrateTimer;
  Map<String, dynamic>? _taskDetails;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    // Play alarm sound directly
    _playAlarmSound();
    _startVibration();
    // Fetch additional task details if needed
    _fetchTaskDetails();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopVibration();
    _audioService.stopAlarmSound();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resume vibration if app comes back to foreground
      _startVibration();
    } else if (state == AppLifecycleState.paused) {
      // Stop vibration if app goes to background
      _stopVibration();
    }
  }

  Future<void> _initializeServices() async {
    try {
      print('🔔 Initializing alarm screen services...');
      await _audioService.initialize();
      setState(() => _isLoading = false);
      print('✅ Alarm screen services initialized successfully');
    } catch (e) {
      print('❌ Error initializing alarm screen services: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTaskDetails() async {
    if (widget.taskId == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/${widget.taskId}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _taskDetails = json.decode(response.body);
          print('✅ Task details fetched: $_taskDetails');
        });
      }
    } catch (e) {
      print('❌ Error fetching task details: $e');
    }
  }

  Future<void> _playAlarmSound() async {
    try {
      await _audioService.playAlarmSound();
      print('🔔 Alarm sound started in AlarmScreen');
    } catch (e) {
      print('❌ Error playing alarm sound in AlarmScreen: $e');
    }
  }

  void _startVibration() {
    _stopVibration(); // Stop any existing vibration
    
    // Vibrate every 1.5 seconds
    _vibrateTimer = Timer.periodic(Duration(milliseconds: 1500), (_) {
      HapticFeedback.heavyImpact();
      Future.delayed(Duration(milliseconds: 500), () {
        HapticFeedback.heavyImpact();
      });
    });
  }

  void _stopVibration() {
    if (_vibrateTimer != null) {
      _vibrateTimer!.cancel();
      _vibrateTimer = null;
    }
  }

  // Format date string for display
  String _formatDate(String? dateString) {
    if (dateString == null) return 'No date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _snoozeAlarm() async {
    try {
      // Stop alarm sound and vibration
      await _audioService.stopAlarmSound();
      _stopVibration();

      if (widget.taskId == null || widget.alarmId == null) {
        throw Exception('Invalid task or alarm ID');
      }

      // Use the shared snooze UI
      await _notificationService.showSnoozeUI(
        context: context,
        taskId: widget.taskId!,
        alarmId: widget.alarmId!,
        taskTitle: widget.taskTitle ?? 'Task Alarm',
        onSnoozeComplete: () {
          // Close the alarm screen after successful snooze
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      );
    } catch (e) {
      print('❌ Error snoozing alarm: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to snooze alarm')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _dismissAlarm() async {
    try {
      // Stop alarm sound and vibration
      await _audioService.stopAlarmSound();
      _stopVibration();

      // Show loading indicator
      setState(() => _isLoading = true);

      if (widget.taskId == null || widget.alarmId == null) {
        throw Exception('Invalid task or alarm ID');
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/tasks/${widget.taskId}/acknowledge_alarm'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'alarm_id': widget.alarmId,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Alarm acknowledged successfully');
      } else {
        print('❌ Failed to acknowledge alarm: ${response.statusCode}');
        print('❌ Error response: ${response.body}');
      }
      
      // Close the alarm screen regardless of API response
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Error acknowledging alarm: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get task details either from the widget parameters or fetched data
    final String taskTitle = widget.taskTitle ?? _taskDetails?['title'] ?? 'Task Alarm';
    final String assigneeName = _taskDetails?['assignee_name'] ?? widget.assigneeName ?? 'Unknown';
    final String dueDate = _formatDate(widget.dueDate ?? _taskDetails?['due_date']);
    // Get theme color instead of hardcoded red
    final Color themeColor = Theme.of(context).primaryColor;

    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from dismissing the alarm
        _dismissAlarm();
        return false;
      },
      child: Scaffold(
        backgroundColor: themeColor,
        appBar: AppBar(
          backgroundColor: themeColor,
          title: Text('ALARM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          automaticallyImplyLeading: false,
        ),
        body: _isLoading ? 
          Center(child: CircularProgressIndicator(color: Colors.white)) :
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.alarm_on,
                    size: 80,
                    color: Colors.white,
                  ),
                  SizedBox(height: 20),
                  Text(
                    taskTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Card(
                    color: themeColor.withOpacity(0.8),
                    margin: EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.person, 'Assigned to: $assigneeName'),
                          SizedBox(height: 8),
                          _infoRow(Icons.calendar_today, 'Due date: $dueDate'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _snoozeAlarm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        child: Text('SNOOZE'),
                      ),
                      ElevatedButton(
                        onPressed: _dismissAlarm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        child: Text('DISMISS'),
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

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
} 