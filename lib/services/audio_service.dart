import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  AudioService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _player.setSource(AssetSource('sounds/notification.mp3'));
      _isInitialized = true;
      debugPrint('🔊 AudioService initialized successfully');
    } catch (e) {
      debugPrint('❌ AudioService initialization error: $e');
      // Don't throw, just log the error
    }
  }

  Future<void> playNotificationSound() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Stop any current playback
      await _player.stop();
      
      // Reset to beginning
      await _player.seek(Duration.zero);
      
      // Play the sound
      await _player.play(AssetSource('sounds/notification.mp3'));
      debugPrint('🔊 Playing notification sound');
    } catch (e) {
      debugPrint('❌ Error playing notification sound: $e');
      // Don't throw, just log the error
    }
  }

  void dispose() {
    _player.dispose();
    _isInitialized = false;
  }
} 