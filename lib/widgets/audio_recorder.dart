import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart' as record_pkg;
import 'package:path_provider/path_provider.dart';

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
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Audio Note (optional)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!_isRecording && !_hasRecording)
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: _startRecording,
                  color: Theme.of(context).primaryColor,
                  tooltip: 'Start Recording',
                ),
              if (_isRecording)
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stopRecording,
                  color: Colors.red,
                  tooltip: 'Stop Recording',
                ),
              if (_hasRecording) ...[
                const Icon(Icons.check_circle, color: Colors.green),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteRecording,
                  color: Colors.red,
                  tooltip: 'Delete Recording',
                ),
              ],
            ],
          ),
          if (_isRecording)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Recording in progress...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 