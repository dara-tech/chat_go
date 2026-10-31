import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/voice/voice_player_controller.dart';
import '../../../core/voice/voice_service.dart';

class ChatVoiceRecorderBar extends StatelessWidget {
  final bool isRecording;
  final bool isPreviewing;
  final VoiceRecordingResult? previewRecording;
  final VoidCallback onCancel;
  final VoidCallback onLockOrPreview;
  final VoidCallback onSend;

  const ChatVoiceRecorderBar({
    super.key,
    required this.isRecording,
    required this.isPreviewing,
    required this.previewRecording,
    required this.onCancel,
    required this.onLockOrPreview,
    required this.onSend,
  });

  static String formatVoiceDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      return _buildVoiceRecordingBar();
    } else if (isPreviewing && previewRecording != null) {
      return _buildVoicePreviewBar(previewRecording!);
    }
    return const SizedBox.shrink();
  }

  Widget _buildVoiceRecordingBar() {
    final voiceService = VoiceService.instance;
    return Container(
      key: const ValueKey('voice_recording_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.40),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Cancel / Trash button
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.trash,
                  size: 19,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Pulsing red indicator & timer
          ValueListenableBuilder<Duration>(
            valueListenable: voiceService.durationNotifier,
            builder: (context, duration, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatVoiceDuration(duration),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LiquidGlassTheme.textPrimary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),

          // Live audio waveform
          Expanded(
            child: ValueListenableBuilder<List<double>>(
              valueListenable: voiceService.liveWaveformNotifier,
              builder: (context, samples, _) {
                final displaySamples = samples.length > 25
                    ? samples.sublist(samples.length - 25)
                    : samples;
                return SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(displaySamples.length, (idx) {
                      final h = (24 * displaySamples[idx]).clamp(3.0, 24.0);
                      return Container(
                        width: 2.2,
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 1.2),
                        decoration: BoxDecoration(
                          color: LiquidGlassTheme.accentBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),

          // Lock / Stop to Preview button
          GestureDetector(
            onTap: onLockOrPreview,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.inputFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: LiquidGlassTheme.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.pause_fill,
                size: 17,
                color: LiquidGlassTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Send button
          GestureDetector(
            onTap: onSend,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.accentBlue,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.arrow_up,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePreviewBar(VoiceRecordingResult preview) {
    final player = VoicePlayerController.instance;
    final totalDur = Duration(milliseconds: preview.durationMs);

    return Container(
      key: const ValueKey('voice_preview_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: LiquidGlassTheme.borderSubtle,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Discard button
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.trash,
                  size: 19,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Play / Pause preview button
          AnimatedBuilder(
            animation: Listenable.merge([
              player.activeMessageIdNotifier,
              player.isPlayingNotifier,
            ]),
            builder: (context, _) {
              final isPlaying = player.activeMessageId == 'preview_temp' &&
                  player.isPlayingNotifier.value;
              return GestureDetector(
                onTap: () {
                  player.playOrPause(
                    messageId: 'preview_temp',
                    audioUrl: preview.path,
                    initialDuration: totalDur,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.accentBlue.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isPlaying
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      size: 18,
                      color: LiquidGlassTheme.accentBlue,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),

          // Preview duration
          Text(
            formatVoiceDuration(totalDur),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LiquidGlassTheme.textPrimary,
            ),
          ),
          const Spacer(),

          // Send button
          GestureDetector(
            onTap: onSend,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.accentBlue,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.arrow_up,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
