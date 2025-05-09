import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import './audio_recorder.dart';
import '../theme/colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class SnoozeDialog extends StatefulWidget {
  final String notificationId;
  final Function onSnoozeComplete;

  const SnoozeDialog({
    Key? key,
    required this.notificationId,
    required this.onSnoozeComplete,
  }) : super(key: key);

  @override
  _SnoozeDialogState createState() => _SnoozeDialogState();
}

class _SnoozeDialogState extends State<SnoozeDialog> {
  final TextEditingController _reasonController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  String? _audioData;
  String? _audioFilePath;
  int? _audioDuration;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  bool get _canSnooze => _reasonController.text.trim().isNotEmpty || _audioData != null;

  @override
  void dispose() {
    _reasonController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }
    String? path = _audioFilePath;
    if ((path == null || path.isEmpty) && _audioData != null) {
      // Save base64 to temp file
      final tempDir = await getTemporaryDirectory();
      path = '${tempDir.path}/snooze_audio_preview.m4a';
      final file = File(path);
      await file.writeAsBytes(base64Decode(_audioData!));
    }
    if (path == null) return;
    await _audioPlayer.play(DeviceFileSource(path));
    setState(() => _isPlaying = true);
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _isPlaying = false);
    });
  }

  Future<void> _handleSnooze() async {
    if (!_canSnooze) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please provide either a reason or a voice note to snooze',
            style: TextStyle(color: AppColors.white),
          ),
          backgroundColor: AppColors.pending,
        ),
      );
      return;
    }

    Map<String, dynamic>? audioNote;
    if (_audioData != null) {
      audioNote = {
        'audio_data': _audioData,
        'filename': 'snooze_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        'duration': _audioDuration ?? 0,
      };
    }

    try {
      await _notificationService.snoozeNotification(
        widget.notificationId,
        _selectedDate,
        reason: _reasonController.text.trim(),
        audioNote: audioNote,
      );
      widget.onSnoozeComplete();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to snooze notification: $e',
              style: TextStyle(color: AppColors.white),
            ),
            backgroundColor: AppColors.pending,
          ),
        );
      }
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Snooze Notification',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: ListTile(
                  title: Text(
                    'Snooze until: ${_selectedDate.toString().split('.')[0]}',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                    ),
                  ),
                  trailing: Icon(
                    Icons.calendar_today,
                    color: AppColors.accentCyan,
                  ),
                  onTap: _selectDateTime,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                style: TextStyle(color: AppColors.white),
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Reason',
                  labelStyle: TextStyle(color: AppColors.textGrey),
                  hintText: 'Enter reason for snoozing...',
                  hintStyle: TextStyle(color: AppColors.textGrey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accentCyan),
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  helperText: _audioData == null ? 'Required if no voice note is provided' : null,
                  helperStyle: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              VoiceRecorder(
                key: ValueKey(_audioData),
                onRecordingComplete: (String? base64Audio, {String? filePath, int? duration}) {
                  setState(() {
                    _audioData = base64Audio;
                    _audioFilePath = filePath;
                    _audioDuration = duration;
                  });
                },
              ),
              if (_audioFilePath != null || _audioData != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: AppColors.accentCyan),
                      onPressed: _playAudio,
                    ),
                    const SizedBox(width: 8),
                    Text('Preview Snooze Audio', style: TextStyle(color: AppColors.textGrey)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _audioData = null;
                          _audioFilePath = null;
                          _audioDuration = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _reasonController.text.trim().isEmpty ? 'Required if no reason is provided' : '',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textGrey,
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _canSnooze ? _handleSnooze : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.background,
                      disabledBackgroundColor: AppColors.textGrey.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Snooze',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 