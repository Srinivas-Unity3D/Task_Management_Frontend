import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import './audio_recorder.dart';

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

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSnooze() async {
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
          SnackBar(content: Text('Failed to snooze notification: $e')),
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
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  'Snooze until: ${_selectedDate.toString().split('.')[0]}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDateTime,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason for snoozing...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              VoiceRecorder(
                onRecordingComplete: (String? base64Audio) {
                  setState(() => _audioData = base64Audio);
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _handleSnooze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    child: const Text('Snooze'),
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