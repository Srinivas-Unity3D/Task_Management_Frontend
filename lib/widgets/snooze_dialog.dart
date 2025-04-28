import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import './audio_recorder.dart';
import '../theme/colors.dart';

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
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));

  bool get _canSnooze => _reasonController.text.trim().isNotEmpty || _audioData != null;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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

    try {
      await _notificationService.snoozeNotification(
        widget.notificationId,
        _selectedDate,
        reason: _reasonController.text.trim(),
        audioNote: _audioData,
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
                onRecordingComplete: (String? base64Audio) {
                  setState(() => _audioData = base64Audio);
                },
              ),
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