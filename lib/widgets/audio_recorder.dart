import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart' as record_pkg;
import 'package:path_provider/path_provider.dart';
import '../theme/colors.dart';

class VoiceRecorder extends StatefulWidget {
  final Function(String?) onRecordingComplete;

  const VoiceRecorder({
    Key? key,
    required this.onRecordingComplete,
  }) : super(key: key);

  @override
  _VoiceRecorderState createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  bool _isRecording = false;
  final record_pkg.AudioRecorder _audioRecorder = record_pkg.AudioRecorder();
  String? _recordingPath;
  bool _hasRecording = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _recordingPath = '${directory.path}/audio_note.m4a';
        
        if (_recordingPath != null) {
          await _audioRecorder.start(
            record_pkg.RecordConfig(
              encoder: record_pkg.AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: _recordingPath!,
          );
          
          setState(() {
            _isRecording = true;
            _hasRecording = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Audio = base64Encode(bytes);
          widget.onRecordingComplete(base64Audio);
          setState(() => _hasRecording = true);
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    } finally {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _deleteRecording() async {
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    widget.onRecordingComplete(null);
    setState(() => _hasRecording = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Audio Note (optional)',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!_isRecording && !_hasRecording)
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: _startRecording,
                  color: AppColors.accentCyan,
                  tooltip: 'Start Recording',
                ),
              if (_isRecording)
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stopRecording,
                  color: AppColors.pending,
                  tooltip: 'Stop Recording',
                ),
              if (_hasRecording) ...[
                Icon(
                  Icons.check_circle,
                  color: AppColors.accentCyan,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteRecording,
                  color: AppColors.pending,
                  tooltip: 'Delete Recording',
                ),
              ],
            ],
          ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Recording in progress...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 