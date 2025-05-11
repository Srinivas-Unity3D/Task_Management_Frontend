import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({Key? key}) : super(key: key);

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final NotificationService _notificationService = NotificationService();
  final AudioService _audioService = AudioService();
  final AudioPlayer _directPlayer = AudioPlayer(); // Direct player for testing
  List<Map<String, dynamic>> _alarms = [];
  bool _isLoading = true;
  bool _isAlarmActive = false;
  Map<String, dynamic>? _activeAlarm;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadAlarms();
    _setupAlarmListener();
  }

  Future<void> _initializeServices() async {
    try {
      print('🔔 Initializing services...');
      await _audioService.initialize();
      print('✅ Services initialized successfully');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  void _setupAlarmListener() {
    print('🔔 Setting up alarm listener');
    _notificationService.onAlarmTriggered = (alarm) {
      print('🔔 Alarm triggered: $alarm');
      setState(() {
        _isAlarmActive = true;
        _activeAlarm = alarm;
      });
      _showAlarmDialog(alarm);
    };
  }

  void _showAlarmDialog(Map<String, dynamic> alarm) async {
    print('🔔 Showing alarm dialog');
    // Play alarm sound
    await _audioService.playAlarmSound();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: Colors.red[900],
            title: const Text(
              'ALARM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm['task_title'] ?? 'Untitled Task',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Due: ${alarm['next_alarm_time']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Frequency: ${alarm['frequency']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  print('🔔 Snooze button pressed');
                  _snoozeAlarm(alarm['task_id'], alarm['alarm_id']);
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Snooze'),
              ),
              TextButton(
                onPressed: () {
                  print('🔔 Acknowledge button pressed');
                  _acknowledgeAlarm(alarm['task_id'], alarm['alarm_id']);
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Acknowledge'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadAlarms() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/alarms'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> alarmsJson = json.decode(response.body);
        setState(() {
          _alarms = alarmsJson.map((alarm) => Map<String, dynamic>.from(alarm)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load alarms');
      }
    } catch (e) {
      print('🔔 Error loading alarms: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading alarms: $e')),
        );
      }
    }
  }

  Future<void> _acknowledgeAlarm(String taskId, String alarmId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/tasks/$taskId/acknowledge_alarm'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'alarm_id': alarmId,
        }),
      );

      if (response.statusCode == 200) {
        // Remove the acknowledged alarm from the list
        setState(() {
          _alarms.removeWhere((alarm) => 
            alarm['task_id'] == taskId && alarm['alarm_id'] == alarmId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarm acknowledged')),
        );
      }
    } catch (e) {
      print('Error acknowledging alarm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to acknowledge alarm')),
      );
    }
  }

  Future<void> _snoozeAlarm(String taskId, String alarmId) async {
    try {
      final DateTime snoozeUntil = DateTime.now().add(const Duration(minutes: 30));
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/tasks/$taskId/snooze_alarm'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'alarm_id': alarmId,
          'snooze_until': snoozeUntil.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        // Remove the snoozed alarm from the list
        setState(() {
          _alarms.removeWhere((alarm) => 
            alarm['task_id'] == taskId && alarm['alarm_id'] == alarmId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarm snoozed for 30 minutes')),
        );
      }
    } catch (e) {
      print('Error snoozing alarm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to snooze alarm')),
      );
    }
  }

  // Direct method to play raw sound on Android
  Future<void> _playRawAlarmSound() async {
    try {
      print('🔊 Playing raw alarm sound directly');
      // First try with default configuration
      await _directPlayer.play(AssetSource('alarm.mp3'));
    } catch (e) {
      print('❌ Error playing raw alarm sound: $e');
      try {
        // Try with explicit configuration
        print('🔄 Trying alternative method');
        await _directPlayer.setSource(AssetSource('alarm.mp3'));
        await _directPlayer.resume();
      } catch (e) {
        print('❌ Second attempt failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlarms,
          ),
          IconButton(
            icon: const Icon(Icons.alarm),
            onPressed: () async {
              print('🔔 Test alarm button pressed');
              try {
                // Play sound directly for testing
                await _playRawAlarmSound();
                
                // Show test dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.red[900],
                    title: const Text(
                      'ALARM TEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: const Text(
                      'This is a test alarm. Did you hear the sound?',
                      style: TextStyle(color: Colors.white),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('YES'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sound not playing. Check if sound files are in the correct location.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('NO'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                print('❌ Error in test alarm: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            tooltip: 'Test Alarm',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
              ? const Center(
                  child: Text(
                    'No active alarms',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = _alarms[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          alarm['task_title'] ?? 'Untitled Task',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Due: ${alarm['next_alarm_time']}',
                              style: const TextStyle(
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'Frequency: ${alarm['frequency']}',
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.snooze),
                              onPressed: () => _snoozeAlarm(
                                alarm['task_id'],
                                alarm['alarm_id'],
                              ),
                              tooltip: 'Snooze',
                            ),
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () => _acknowledgeAlarm(
                                alarm['task_id'],
                                alarm['alarm_id'],
                              ),
                              tooltip: 'Acknowledge',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 