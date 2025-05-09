import 'package:audioplayers/audioplayers.dart';

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
      await _player.setSource(AssetSource('sounds/notification.mp3'));
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
      
      // Load and play the sound
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