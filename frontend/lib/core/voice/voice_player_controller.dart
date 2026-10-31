import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../api/api_client.dart';

/// Centralized audio player controller to coordinate single playback across all chat bubbles.
class VoicePlayerController {
  static final VoicePlayerController instance = VoicePlayerController._internal();

  VoicePlayerController._internal() {
    _initAudioPlayer();
  }

  late final AudioPlayer _player;
  String? _activeUrl;
  dynamic _activeMessageId;

  final ValueNotifier<dynamic> activeMessageIdNotifier = ValueNotifier<dynamic>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);

  StreamSubscription? _playerStateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  void _initAudioPlayer() {
    _player = AudioPlayer();

    _playerStateSub = _player.playerStateStream.listen((state) {
      final playing = state.playing && state.processingState != ProcessingState.completed;
      final buffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;

      isPlayingNotifier.value = playing;
      isBufferingNotifier.value = buffering;

      if (state.processingState == ProcessingState.completed) {
        positionNotifier.value = Duration.zero;
        _player.seek(Duration.zero);
        _player.pause();
      }
    });

    _posSub = _player.positionStream.listen((pos) {
      positionNotifier.value = pos;
    });

    _durSub = _player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        durationNotifier.value = dur;
      }
    });
  }

  dynamic get activeMessageId => _activeMessageId;
  String? get activeUrl => _activeUrl;
  bool isMessagePlaying(dynamic messageId) =>
      _activeMessageId == messageId && isPlayingNotifier.value;

  Future<void> playOrPause({
    required dynamic messageId,
    required String audioUrl,
    Duration? initialDuration,
  }) async {
    try {
      if (_activeMessageId == messageId) {
        // Toggle play/pause for same message
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }
        return;
      }

      // Switch to new message
      await _player.stop();
      _activeMessageId = messageId;
      _activeUrl = audioUrl;
      activeMessageIdNotifier.value = messageId;

      if (initialDuration != null && initialDuration > Duration.zero) {
        durationNotifier.value = initialDuration;
      }
      positionNotifier.value = Duration.zero;

      if (audioUrl.trim().isEmpty) {
        debugPrint('[VoicePlayerController] Cannot play: empty audioUrl');
        return;
      }

      var resolvedUrl = ApiClient.resolveAvatarUrl(audioUrl);
      if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://') || resolvedUrl.startsWith('blob:')) {
        await _player.setUrl(resolvedUrl);
      } else {
        if (resolvedUrl.startsWith('file://')) {
          try {
            resolvedUrl = Uri.parse(resolvedUrl).toFilePath();
          } catch (_) {
            resolvedUrl = resolvedUrl.replaceFirst('file://', '');
          }
        }
        await _player.setFilePath(resolvedUrl);
      }

      await _player.play();
    } catch (e) {
      debugPrint('[VoicePlayerController] Error playing audio ($audioUrl): $e');
      _activeMessageId = null;
      activeMessageIdNotifier.value = null;
      isPlayingNotifier.value = false;
    }
  }

  Future<void> seekFraction(double fraction) async {
    final dur = durationNotifier.value;
    if (dur > Duration.zero) {
      final target = Duration(milliseconds: (dur.inMilliseconds * fraction.clamp(0.0, 1.0)).round());
      await _player.seek(target);
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _activeMessageId = null;
      activeMessageIdNotifier.value = null;
      isPlayingNotifier.value = false;
    } catch (_) {}
  }

  void dispose() {
    _playerStateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
  }
}
