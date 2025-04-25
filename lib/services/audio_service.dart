import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  Future<void> initialize() async {
    try {
      if (!_isInitialized) {
        print('🔊 AudioService - Initializing...');
        await _audioPlayer.setReleaseMode(ReleaseMode.release); // Release resources after playing
        await _audioPlayer.setPlayerMode(PlayerMode.lowLatency); // Better for short sounds
        await _audioPlayer.setSourceAsset('sounds/notification.mp3');
        _audioPlayer.onPlayerComplete.listen((event) {
          print('🔊 AudioService - Sound playback completed');
        });
        _audioPlayer.onPlayerStateChanged.listen((state) {
          print('🔊 AudioService - Player state changed: $state');
        });
        _isInitialized = true;
        print('🔊 AudioService - Initialized successfully');
      }
    } catch (e) {
      print('🔊 AudioService - Error during initialization: $e');
      _isInitialized = false;
    }
  }

  Future<void> playNotificationSound() async {
    try {
      print('🔊 AudioService - Attempting to play notification sound');
      if (!_isInitialized) {
        print('🔊 AudioService - Not initialized, initializing now...');
        await initialize();
      }

      // Stop any currently playing sound
      await _audioPlayer.stop();
      
      // Set volume to max
      await _audioPlayer.setVolume(1.0);
      
      // Play the sound
      print('🔊 AudioService - Playing sound...');
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      print('🔊 AudioService - Play command sent successfully');
    } catch (e) {
      print('🔊 AudioService - Error playing notification sound: $e');
      // Try to reinitialize on error
      _isInitialized = false;
      try {
        print('🔊 AudioService - Attempting to reinitialize...');
        await initialize();
        print('🔊 AudioService - Retrying playback...');
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      } catch (e) {
        print('🔊 AudioService - Error during retry: $e');
      }
    }
  }

  void dispose() {
    print('🔊 AudioService - Disposing...');
    _audioPlayer.dispose();
    _isInitialized = false;
  }
} 