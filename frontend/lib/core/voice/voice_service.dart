import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'voice_file_helper.dart';

class VoiceRecordingResult {
  final String path;
  final Uint8List bytes;
  final int durationMs;
  final List<double> waveform;

  VoiceRecordingResult({
    required this.path,
    required this.bytes,
    required this.durationMs,
    required this.waveform,
  });

  String get waveformJson => jsonEncode(waveform);
}

enum VoiceRecordingState {
  idle,
  recording,
  previewing,
}

class VoiceService {
  static final VoiceService instance = VoiceService._internal();

  VoiceService._internal();

  AudioRecorder? _recorder;
  bool _isPluginMissing = false;

  AudioRecorder? _getRecorder() {
    if (_isPluginMissing) return null;
    if (_recorder != null) return _recorder;
    try {
      _recorder = AudioRecorder();
      return _recorder;
    } catch (e) {
      debugPrint('[VoiceService] Native AudioRecorder not available: $e');
      _isPluginMissing = true;
      return null;
    }
  }

  Timer? _recordTimer;
  DateTime? _recordStartTime;
  String? _recordedPath;

  final ValueNotifier<VoiceRecordingState> stateNotifier =
      ValueNotifier<VoiceRecordingState>(VoiceRecordingState.idle);
  final ValueNotifier<Duration> durationNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<List<double>> liveWaveformNotifier =
      ValueNotifier<List<double>>([]);

  VoiceRecordingState get state => stateNotifier.value;
  Duration get duration => durationNotifier.value;
  List<double> get liveWaveform => liveWaveformNotifier.value;
  String? get recordedPath => _recordedPath;

  Future<bool> hasPermission() async {
    try {
      final rec = _getRecorder();
      if (rec == null) return false;
      return await rec.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<bool> startRecording() async {
    try {
      final rec = _getRecorder();
      if (rec == null) {
        debugPrint('[VoiceService] AudioRecorder unavailable. Rebuild app with flutter run.');
        return false;
      }

      final permitted = await hasPermission();
      if (!permitted) {
        return false;
      }

      try {
        await rec.stop(); // Ensure any dangling recording is stopped
      } catch (_) {}

      final config = kIsWeb
          ? const RecordConfig(
              encoder: AudioEncoder.opus,
              bitRate: 64000,
              sampleRate: 44100,
            )
          : const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            );

      final recordPath = await VoiceFileHelper.prepareRecordPath();
      await rec.start(config, path: recordPath);
      _recordStartTime = DateTime.now();
      _recordedPath = recordPath.isNotEmpty ? recordPath : null;
      stateNotifier.value = VoiceRecordingState.recording;
      durationNotifier.value = Duration.zero;
      liveWaveformNotifier.value = [];

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (_recordStartTime != null) {
          final elapsed = DateTime.now().difference(_recordStartTime!);
          durationNotifier.value = elapsed;

          try {
            final amp = await rec.getAmplitude();
            // amp.current is in dBFS (-60 to 0)
            final currentDb = amp.current.clamp(-55.0, 0.0);
            final normalized = ((currentDb + 55.0) / 55.0).clamp(0.12, 1.0);

            final currentList = List<double>.from(liveWaveformNotifier.value);
            currentList.add(normalized);
            // Keep at most 45 recent amplitude points for live rendering
            if (currentList.length > 45) {
              currentList.removeAt(0);
            }
            liveWaveformNotifier.value = currentList;
          } catch (_) {}
        }
      });

      return true;
    } catch (e) {
      debugPrint('[VoiceService] Start recording error: $e');
      stateNotifier.value = VoiceRecordingState.idle;
      _recordTimer?.cancel();
      return false;
    }
  }

  Future<VoiceRecordingResult?> stopRecording() async {
    try {
      _recordTimer?.cancel();
      final finalDuration = durationNotifier.value;
      final stopPath = await _recorder?.stop();
      final path = (stopPath != null && stopPath.isNotEmpty) ? stopPath : _recordedPath;

      stateNotifier.value = VoiceRecordingState.idle;
      if (path == null || path.isEmpty) {
        return null;
      }

      _recordedPath = path;

      // Read audio bytes reliably across platforms
      final Uint8List bytes = await VoiceFileHelper.readFileBytes(path);

      // Generate normalized 28-bar waveform summary for persistent bubble
      final fullSamples = liveWaveformNotifier.value;
      final normalizedWaveform = _compressWaveform(fullSamples, 28);

      return VoiceRecordingResult(
        path: path,
        bytes: bytes,
        durationMs: finalDuration.inMilliseconds > 0 ? finalDuration.inMilliseconds : 1000,
        waveform: normalizedWaveform,
      );
    } catch (e) {
      debugPrint('[VoiceService] Stop recording error: $e');
      stateNotifier.value = VoiceRecordingState.idle;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _recordTimer?.cancel();
      await _recorder?.stop();
      _recordedPath = null;
      durationNotifier.value = Duration.zero;
      liveWaveformNotifier.value = [];
      stateNotifier.value = VoiceRecordingState.idle;
    } catch (_) {
      stateNotifier.value = VoiceRecordingState.idle;
    }
  }

  List<double> _compressWaveform(List<double> samples, int targetBars) {
    if (samples.isEmpty) {
      return List.filled(targetBars, 0.35);
    }
    if (samples.length <= targetBars) {
      final padded = List<double>.from(samples);
      while (padded.length < targetBars) {
        padded.add(padded.last);
      }
      return padded;
    }

    final result = <double>[];
    final chunkSize = samples.length / targetBars;
    for (int i = 0; i < targetBars; i++) {
      final start = (i * chunkSize).floor();
      final end = ((i + 1) * chunkSize).ceil().clamp(0, samples.length);
      final slice = samples.sublist(start, end);
      final avg = slice.reduce((a, b) => a + b) / slice.length;
      result.add((avg * 100).round() / 100);
    }
    return result;
  }

  void dispose() {
    _recordTimer?.cancel();
    _recorder?.dispose();
  }
}
