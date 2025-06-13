// import 'package:audioplayers/audioplayers.dart';
// import 'dart:io';
// import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart';
//
// class AudioService {
//   static final AudioService _instance = AudioService._internal();
//   factory AudioService() => _instance;
//   AudioService._internal();
//
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   final AudioPlayer _notificationPlayer = AudioPlayer();
//   bool _isInitialized = false;
//
//   Future<void> initialize() async {
//     if (_isInitialized) return;
//
//     try {
//       print('🔊 Initializing AudioService...');
//       await _audioPlayer.setReleaseMode(ReleaseMode.loop);
//       await _audioPlayer.setVolume(1.0);
//       await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
//       _isInitialized = true;
//       print('✅ AudioService initialized successfully');
//     } catch (e) {
//       print('❌ Error initializing AudioService: $e');
//     }
//   }
//
//   Future<void> setReleaseMode(ReleaseMode mode) async {
//     try {
//       await _audioPlayer.setReleaseMode(mode);
//     } catch (e) {
//       print('❌ Error setting release mode: $e');
//     }
//   }
//
//   Future<void> setVolume(double volume) async {
//     try {
//       await _audioPlayer.setVolume(volume);
//     } catch (e) {
//       print('❌ Error setting volume: $e');
//     }
//   }
//
//   Future<void> setSource(AssetSource source) async {
//     try {
//       await _audioPlayer.setSource(source);
//     } catch (e) {
//       print('❌ Error setting audio source: $e');
//     }
//   }
//
//   Future<void> playAlarmSound() async {
//     try {
//       if (!_isInitialized) {
//         await initialize();
//       }
//
//       // Stop any existing playback
//       await _audioPlayer.stop();
//
//       // Reset the player state
//       await _audioPlayer.setReleaseMode(ReleaseMode.loop);
//       await _audioPlayer.setVolume(1.0);
//
//       // Set and play the alarm sound
//       await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
//       await _audioPlayer.resume();
//
//       // Keep the screen on while alarm is playing
//       await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//       await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//
//       // Set wake lock
//       await _audioPlayer.setReleaseMode(ReleaseMode.loop);
//       await _audioPlayer.setVolume(1.0);
//
//       print('✅ Alarm sound playing successfully');
//     } catch (e) {
//       print('❌ Error playing alarm sound: $e');
//       // Try to reinitialize and play again
//       try {
//         _isInitialized = false;
//         await initialize();
//         await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
//         await _audioPlayer.resume();
//       } catch (e) {
//         print('❌ Error during retry: $e');
//       }
//     }
//   }
//
//   Future<void> stopAlarmSound() async {
//     try {
//       await _audioPlayer.stop();
//       // Reset system UI mode
//       await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//       // Release wake lock
//       await _audioPlayer.setReleaseMode(ReleaseMode.stop);
//       print('✅ Alarm sound stopped successfully');
//     } catch (e) {
//       print('❌ Error stopping alarm sound: $e');
//     }
//   }
//
//   void dispose() {
//     try {
//       if (_audioPlayer.state != PlayerState.disposed) {
//         _audioPlayer.dispose();
//       }
//       _isInitialized = false;
//     } catch (e) {
//       print('❌ Error disposing AudioService: $e');
//     }
//   }
//
//   Future<void> setAudioSource(String source) async {
//     try {
//       await _audioPlayer.setSource(AssetSource(source));
//       print('✅ Audio source set successfully');
//     } catch (e) {
//       print('❌ Error setting audio source: $e');
//     }
//   }
//
//   Future<void> setLoopMode(ReleaseMode mode) async {
//     try {
//       await _audioPlayer.setReleaseMode(mode);
//     } catch (e) {
//       print('❌ Error setting loop mode: $e');
//     }
//   }
//
//   Future<void> resume() async {
//     try {
//       await _audioPlayer.resume();
//     } catch (e) {
//       print('❌ Error resuming audio: $e');
//     }
//   }
//
//   Future<void> pause() async {
//     try {
//       await _audioPlayer.pause();
//     } catch (e) {
//       print('❌ Error pausing audio: $e');
//     }
//   }
//
//   Future<void> seek(Duration position) async {
//     try {
//       await _audioPlayer.seek(position);
//     } catch (e) {
//       print('❌ Error seeking audio: $e');
//     }
//   }
//
//   Stream<PlayerState> get playerStateStream => _audioPlayer.onPlayerStateChanged;
//
//   Future<void> playNotificationSound() async {
//     try {
//       if (!_isInitialized) {
//         await initialize();
//       }
//       await _notificationPlayer.setVolume(1.0);
//       await _notificationPlayer.setReleaseMode(ReleaseMode.release);
//       await _notificationPlayer.resume();
//       print('✅ Notification sound playing');
//     } catch (e) {
//       print('❌ Error playing notification sound: $e');
//     }
//   }
// }