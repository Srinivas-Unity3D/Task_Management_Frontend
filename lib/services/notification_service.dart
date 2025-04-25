import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  NotificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _audioPlayer.setSource(AssetSource('sounds/notification.mp3'));
    _isInitialized = true;
  }

  Future<void> playNotificationSound() async {
    try {
      // Stop any previous playing sound
      await _audioPlayer.stop();
      // Set the source again to ensure it's ready to play
      await _audioPlayer.setSource(AssetSource('sounds/notification.mp3'));
      // Play the sound
      await _audioPlayer.resume();
    } catch (e) {
      print('Error playing notification sound: $e');
    }
  }

  Future<void> vibrate() async {
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      print('Error during vibration: $e');
    }
  }

  Future<void> handleNewNotification() async {
    await playNotificationSound();
    await vibrate();
  }

  void dispose() {
    _audioPlayer.dispose();
    _isInitialized = false;
  }
} 