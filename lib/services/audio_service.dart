import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isDisposed = false;

  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      print('🎵 [Audio] Initializing audio service...');
      _isInitialized = true;
      print('🎵 [Audio] Audio service initialized successfully');
    } catch (e) {
      print('❌ [Audio] Error initializing audio service: $e');
      _isInitialized = false;
    }
  }

  Future<void> playNotificationSound() async {
    print('🎵 [Audio] Attempting to play notification sound...');
    
    try {
      // Stop any existing playback
      await _player.stop();
      
      // Reset the player state
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.setVolume(1.0);
      
      // Play from raw resource (Android only)
      print('🎵 [Audio] Playing notification sound from raw resource');
      await _player.play(AssetSource('sounds/notification.mp3'));
      print('🎵 [Audio] Notification sound played successfully');
    } catch (e) {
      print('❌ [Audio] Error playing notification sound: $e');
      print('🔄 [Audio] Attempting to reinitialize...');
      
      // Try to reinitialize and play again
      _isInitialized = false;
      await initialize();
      try {
        print('🎵 [Audio] Retrying playback...');
        await _player.play(AssetSource('sounds/notification.mp3'));
        print('🎵 [Audio] Retry successful');
      } catch (e) {
        print('❌ [Audio] Retry failed: $e');
      }
    }
  }

  Future<void> playAlarmSound() async {
    print('🎵 [Audio] Attempting to play alarm sound...');
    
    try {
      // Stop any existing playback
      await _player.stop();
      
      // Reset the player state
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.setVolume(1.0);
      
      // Play directly from raw resource for Android
      print('🎵 [Audio] Playing alarm sound from raw resource');
      await _player.play(AssetSource('sounds/alarm.mp3'));
      print('🎵 [Audio] Alarm sound played successfully');
    } catch (e) {
      print('❌ [Audio] Error playing alarm sound: $e');
      print('🔄 [Audio] Attempting to reinitialize...');
      
      // Try to reinitialize and play again
      _isInitialized = false;
      await initialize();
      try {
        print('🎵 [Audio] Retrying alarm playback...');
        await _player.play(AssetSource('sounds/alarm.mp3'));
        print('🎵 [Audio] Retry successful');
      } catch (e) {
        print('❌ [Audio] Retry failed: $e');
      }
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    
    try {
      print('🎵 [Audio] Disposing audio service...');
      _isDisposed = true;
      await _player.stop();
      await _player.dispose();
      print('🎵 [Audio] Audio service disposed successfully');
    } catch (e) {
      print('❌ [Audio] Error disposing audio service: $e');
    }
  }
} 