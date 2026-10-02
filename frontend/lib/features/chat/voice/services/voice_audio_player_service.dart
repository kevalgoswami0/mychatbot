import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/utils/logger.dart';

/// Robust sequential audio player service for WAV TTS playback.
/// Ensures sequential queueing without overlapping audio, supports 1.1x playback speed,
/// and broadcasts speaking state for AI orb reactivity.
class VoiceAudioPlayerService {
  VoiceAudioPlayerService._internal() {
    _init();
  }

  static final VoiceAudioPlayerService instance = VoiceAudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _queue = [];
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isVoiceSessionActive = false;
  double _playbackRate = 1.1;

  /// Whether a live voice call session is currently active.
  /// Audio playback is strictly gated by this flag so normal chat screen remains silent.
  bool get isVoiceSessionActive => _isVoiceSessionActive;

  /// Activates or deactivates voice audio playback.
  void setVoiceSessionActive(bool active) {
    _isVoiceSessionActive = active;
    if (!active) {
      stop();
    }
  }

  final StreamController<bool> _isSpeakingController =
      StreamController<bool>.broadcast();
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;
  bool get isSpeaking => _isPlaying;

  final StreamController<void> _playbackCompleteController =
      StreamController<void>.broadcast();
  Stream<void> get playbackCompleteStream =>
      _playbackCompleteController.stream;

  StreamSubscription<void>? _completeSubscription;

  void _init() {
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      _playNext();
    });
  }

  /// Add audio WAV bytes to queue and start playing if idle.
  /// Only enqueues if voice session is actively open.
  Future<void> enqueue(Uint8List bytes) async {
    if (!_isVoiceSessionActive) return;
    if (bytes.isEmpty) return;
    _queue.add(bytes);
    if (!_isPlaying) {
      await _playNext();
    }
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) {
      _isPlaying = false;
      _isSpeakingController.add(false);
      _playbackCompleteController.add(null);
      return;
    }

    _isPlaying = true;
    _isSpeakingController.add(true);
    final bytes = _queue.removeAt(0);

    try {
      await _player.setVolume(_isMuted ? 0.0 : 1.0);
      await _player.play(BytesSource(bytes));
      // Set playback speed after starting playback to ensure the audio engine applies it
      await _player.setPlaybackRate(_playbackRate);
    } catch (e, st) {
      AppLogger.error('Voice audio playback error: $e', error: e, stackTrace: st);
      // Try next chunk in case of corrupted frame
      await _playNext();
    }
  }

  /// Configure playback speed (default: 1.1x natural conversational tempo)
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate;
    try {
      await _player.setPlaybackRate(rate);
    } catch (_) {}
  }

  /// Toggle or set mute state
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    try {
      await _player.setVolume(muted ? 0.0 : 1.0);
    } catch (_) {}
  }

  bool get isMuted => _isMuted;

  /// Stop current playback and purge the pending queue immediately
  Future<void> stop() async {
    _queue.clear();
    _isPlaying = false;
    _isSpeakingController.add(false);
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Clean up resources
  Future<void> dispose() async {
    await stop();
    await _completeSubscription?.cancel();
    await _isSpeakingController.close();
    await _playbackCompleteController.close();
    await _player.dispose();
  }
}
