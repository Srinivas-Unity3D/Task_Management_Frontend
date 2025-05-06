import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;

  factory AudioService() {
    return _instance;
  }

  AudioService._internal() {
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      print('🔊 AudioService - Player state changed: $state');
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      print('🔊 AudioService - Sound playback completed');
    });
  }

  Future<void> initialize() async {
    try {
      if (!_isInitialized) {
        print('🔊 AudioService - Initializing...');
        await _audioPlayer.setReleaseMode(ReleaseMode.release);
        await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
        await _audioPlayer.setSourceAsset('sounds/notification.mp3');
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

      // If sound is currently playing, stop it immediately
      if (_isPlaying) {
        print('🔊 AudioService - Stopping current playback');
        await _audioPlayer.stop();
        // Small delay to ensure clean playback
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Set volume and play
      await _audioPlayer.setVolume(1.0);
      print('🔊 AudioService - Playing new sound');
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      print('🔊 AudioService - Play command sent successfully');
    } catch (e) {
      print('🔊 AudioService - Error playing notification sound: $e');
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
    _isPlaying = false;
  }
} 