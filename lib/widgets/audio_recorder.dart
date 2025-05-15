import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart' as record_pkg;
import 'package:path_provider/path_provider.dart';
import '../theme/colors.dart';

class VoiceRecorder extends StatefulWidget {
  final Function(String?, {String? filePath, int? duration}) onRecordingComplete;

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
      print('🎙️ Checking recording permission');
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        
        // Ensure directory exists
        if (!await directory.exists()) {
          print('📁 Creating temporary directory: ${directory.path}');
          await directory.create(recursive: true);
        }
        
        // Create unique filename with timestamp to avoid conflicts
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _recordingPath = '${directory.path}/snooze_notification_${timestamp}.wav';
        
        print('🎙️ Will save recording to: $_recordingPath');
        
        // Make sure the file doesn't exist already
        final file = File(_recordingPath!);
        if (await file.exists()) {
          print('🎙️ Deleting existing file: $_recordingPath');
          try {
            await file.delete();
          } catch (e) {
            print('⚠️ Failed to delete existing file: $e');
          }
        }
        
        print('🎙️ Starting audio recording with WAV format');
        await _audioRecorder.start(
          record_pkg.RecordConfig(
            encoder: record_pkg.AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath!,
        );
        
        print('✅ Recording started successfully');
        setState(() {
          _isRecording = true;
          _hasRecording = false;
        });
      } else {
        print('❌ No permission to record audio');
      }
    } catch (e) {
      print('❌ Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      print('🎙️ Stopping audio recording');
      await _audioRecorder.stop();
      
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('📂 Audio file size: $fileSize bytes');
          
          if (fileSize > 100) { // Only process file if it has content
            try {
              print('🎙️ Reading file bytes for base64 encoding');
              final bytes = await file.readAsBytes();
              final duration = bytes.length ~/ 44; // Better approximation for WAV
              
              print('🎙️ Converting to base64: ${bytes.length} bytes');
              final base64Audio = base64Encode(bytes);
              print('✅ Audio recording processed successfully: $duration ms, ${base64Audio.length} chars base64');
              
              // Pass all information to the callback
              widget.onRecordingComplete(
                base64Audio, 
                filePath: _recordingPath,
                duration: duration
              );
              
              setState(() => _hasRecording = true);
            } catch (e) {
              print('❌ Error processing audio file: $e');
            }
          } else {
            print('⚠️ Audio file too small (${fileSize} bytes), not using it');
          }
        } else {
          print('⚠️ Audio file not found after recording: $_recordingPath');
          
          // Check the directory contents
          final directory = File(_recordingPath!).parent;
          try {
            final files = await directory.list().toList();
            print('📁 Files in directory: ${files.length}');
            for (var f in files) {
              print('📄 - ${f.path} (${await File(f.path).length()} bytes)');
            }
          } catch (e) {
            print('❌ Error listing directory: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Error stopping recording: $e');
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