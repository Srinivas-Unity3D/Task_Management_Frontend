import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer(); // Dedicated player for alarms
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isAlarmPlaying = false;

  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      print('🎵 [Audio] Initializing audio service...');
      
      // Configure regular player
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      
      // Configure dedicated alarm player
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop); // Loop for alarms
      await _alarmPlayer.setVolume(1.0);
      
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
    if (_isAlarmPlaying) {
      print('🎵 [Audio] Alarm sound already playing, not starting another');
      return;
    }
    
    try {
      print('🎵 [Audio] Attempting to play alarm sound...');
      if (!_isInitialized) {
        await initialize();
      }

      // Set up listener for completion
      _alarmPlayer.onPlayerComplete.listen((_) {
        print('✅ [Audio] Playback completed');
      });

      // Set up listener for state changes
      _alarmPlayer.onPlayerStateChanged.listen((state) {
        print('🎵 [Audio] Player state changed: $state');
        if (state == PlayerState.playing) {
          _isAlarmPlaying = true;
        } else if (state == PlayerState.stopped || state == PlayerState.completed) {
          _isAlarmPlaying = false;
        }
      });
      
      // Make sure it's stopped before we begin
      await _alarmPlayer.stop();

      print('🎵 [Audio] Playing alarm sound from assets');
      
      // First try to play directly
      try {
        await _alarmPlayer.play(AssetSource('sounds/alarm.mp3'));
      } catch (e) {
        // If that fails, try with setSource + resume
        print('🎵 [Audio] First play attempt failed, trying alternative method: $e');
        await _alarmPlayer.setSource(AssetSource('sounds/alarm.mp3'));
        await _alarmPlayer.resume();
      }
      
      print('✅ [Audio] Alarm sound started successfully');
      _isAlarmPlaying = true;
    } catch (e) {
      print('❌ [Audio] Error playing alarm sound: $e');
      _isAlarmPlaying = false;
      
      // Try one more approach as a last resort
      try {
        print('🎵 [Audio] Trying last resort method to play alarm');
        final player = AudioPlayer();
        await player.setVolume(1.0);
        await player.setReleaseMode(ReleaseMode.loop);
        await player.play(AssetSource('sounds/alarm.mp3'));
      } catch (e) {
        print('❌ [Audio] Last resort also failed: $e');
      }
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      print('🎵 [Audio] Stopping alarm sound');
      await _alarmPlayer.stop();
      _isAlarmPlaying = false;
      print('✅ [Audio] Alarm sound stopped');
    } catch (e) {
      print('❌ [Audio] Error stopping alarm sound: $e');
      // Try to dispose and recreate as a last resort
      try {
        await _alarmPlayer.dispose();
        // Create a new instance
        final newPlayer = AudioPlayer();
        // We'll lose this reference when this function ends, but at least
        // we've stopped the sound by disposing the original player
      } catch (e) {
        print('❌ [Audio] Error disposing player: $e');
      }
    }
  }

  bool isAlarmPlaying() {
    return _isAlarmPlaying;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    
    try {
      print('🎵 [Audio] Disposing audio service...');
      _isDisposed = true;
      await _player.stop();
      await _player.dispose();
      await _alarmPlayer.dispose();
      print('✅ [Audio] Audio service disposed successfully');
    } catch (e) {
      print('❌ [Audio] Error disposing audio service: $e');
    }
  }
} 