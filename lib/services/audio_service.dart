import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  AudioPlayer? _player;
  bool _isInitialized = false;

  AudioService._internal();

  Future<void> initialize() async {
    try {
      if (!_isInitialized) {
        _player = AudioPlayer();
        _isInitialized = true;
      }
    } catch (e) {
      print('❌ AudioService initialization error: $e');
    }
  }

  Future<void> playNotificationSound() async {
    try {
      if (_isInitialized && _player != null) {
        await _player!.play(AssetSource('sounds/notification.mp3'));
      }
    } catch (e) {
      print('❌ AudioService playback error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      if (_isInitialized && _player != null) {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
        _isInitialized = false;
      }
    } catch (e) {
      print('❌ AudioService disposal error: $e');
      // Even if disposal fails, make sure we clear the references
      _player = null;
      _isInitialized = false;
    }
  }
} 