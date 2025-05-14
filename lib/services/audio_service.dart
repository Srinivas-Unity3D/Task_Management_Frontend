import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isAlarmPlaying = false;

  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      print('🎵 [Audio] Initializing audio service...');
      
      // Set up error handler
      _player.onLog.listen((String msg) {
        print('❌ [Audio] Player error: $msg');
        _isAlarmPlaying = false;
      });
      
      // Set up completion handler
      _player.onPlayerComplete.listen((_) {
        print('✅ [Audio] Playback completed');
        _isAlarmPlaying = false;
      });
      
      // Test if we can access the audio files
      try {
        final manifestContent = await rootBundle.loadString('AssetManifest.json');
        print('🎵 [Audio] Asset manifest loaded');
        
        if (!manifestContent.contains('sounds/alarm.mp3')) {
          print('❌ [Audio] Alarm sound file not found in asset manifest');
        } else {
          print('✅ [Audio] Alarm sound file found in asset manifest');
        }
      } catch (e) {
        print('❌ [Audio] Error loading asset manifest: $e');
      }
      
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
      if (!_isInitialized) {
        print('🔄 [Audio] Service not initialized, initializing now...');
        await initialize();
      }
      
      // Stop any existing playback
      await _player.stop();
      
      // Reset the player state
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      
      // Play the alarm sound
      print('🎵 [Audio] Playing alarm sound from assets');
      await _player.play(AssetSource('sounds/alarm.mp3'));
      _isAlarmPlaying = true;
      print('✅ [Audio] Alarm sound started successfully');
    } catch (e) {
      print('❌ [Audio] Error playing alarm sound: $e');
      print('🔄 [Audio] Attempting to reinitialize...');
      
      // Try to reinitialize and play again
      _isInitialized = false;
      await initialize();
      try {
        print('🎵 [Audio] Retrying alarm playback...');
        await _player.play(AssetSource('sounds/alarm.mp3'));
        _isAlarmPlaying = true;
        print('✅ [Audio] Retry successful');
      } catch (e) {
        print('❌ [Audio] Retry failed: $e');
        _isAlarmPlaying = false;
      }
    }
  }

  Future<void> stopAlarmSound() async {
    if (!_isAlarmPlaying) return;
    
    try {
      print('🎵 [Audio] Stopping alarm sound');
      await _player.stop();
      _isAlarmPlaying = false;
      print('✅ [Audio] Alarm sound stopped successfully');
    } catch (e) {
      print('❌ [Audio] Error stopping alarm sound: $e');
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    
    try {
      print('🎵 [Audio] Disposing audio service...');
      _isDisposed = true;
      await _player.stop();
      await _player.dispose();
      print('✅ [Audio] Audio service disposed successfully');
    } catch (e) {
      print('❌ [Audio] Error disposing audio service: $e');
    }
  }
} 