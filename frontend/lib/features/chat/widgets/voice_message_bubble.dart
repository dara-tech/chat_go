import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme/liquid_glass_theme.dart';
import 'package:frontend/core/voice/voice_player_controller.dart';

class VoiceMessageBubble extends StatelessWidget {
  final dynamic messageId;
  final String audioUrl;
  final int? durationMs;
  final String? waveformJson;
  final bool isMe;
  final bool isRead;
  final bool isPending;
  final String timeFormatted;

  const VoiceMessageBubble({
    super.key,
    required this.messageId,
    required this.audioUrl,
    this.durationMs,
    this.waveformJson,
    required this.isMe,
    required this.isRead,
    this.isPending = false,
    required this.timeFormatted,
  });

  List<double> get _waveformBars {
    if (waveformJson != null && waveformJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(waveformJson!);
        if (decoded is List) {
          return decoded.map((e) => (e as num).toDouble().clamp(0.12, 1.0)).toList();
        }
      } catch (_) {}
    }
    // Default 28 balanced amplitude bars
    return const [
      0.25, 0.40, 0.65, 0.35, 0.80, 0.95, 0.50, 0.35, 0.85, 1.00, 0.60, 0.45,
      0.75, 0.50, 0.30, 0.65, 0.80, 0.90, 0.45, 0.60, 0.75, 0.55, 0.35, 0.60,
      0.40, 0.50, 0.35, 0.20
    ];
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = VoicePlayerController.instance;
    final totalDuration = Duration(milliseconds: durationMs ?? 0);

    return AnimatedBuilder(
      animation: Listenable.merge([
        player.activeMessageIdNotifier,
        player.isPlayingNotifier,
        player.isBufferingNotifier,
        player.positionNotifier,
        player.durationNotifier,
      ]),
      builder: (context, _) {
        final isActive = player.activeMessageId == messageId;
        final isPlaying = isActive && player.isPlayingNotifier.value;
        final isBuffering = isActive && player.isBufferingNotifier.value;
        final currentPosition = isActive ? player.positionNotifier.value : Duration.zero;
        final effectiveTotal = (isActive && player.durationNotifier.value > Duration.zero)
            ? player.durationNotifier.value
            : totalDuration;

        final double progress = effectiveTotal > Duration.zero
            ? (currentPosition.inMilliseconds / effectiveTotal.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        final durationLabel = isPlaying
            ? '${_formatDuration(currentPosition)} / ${_formatDuration(effectiveTotal)}'
            : _formatDuration(effectiveTotal > Duration.zero ? effectiveTotal : const Duration(seconds: 5));

        return Container(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 290),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play/Pause / Buffering Button
                  GestureDetector(
                    onTap: isPending
                        ? null
                        : () => player.playOrPause(
                              messageId: messageId,
                              audioUrl: audioUrl,
                              initialDuration: totalDuration,
                            ),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.24)
                            : LiquidGlassTheme.accentBlue.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isPending
                            ? CupertinoActivityIndicator(
                                radius: 9,
                                color: isMe ? Colors.white : LiquidGlassTheme.accentBlue,
                              )
                            : isBuffering
                                ? CupertinoActivityIndicator(
                                    radius: 9,
                                    color: isMe ? Colors.white : LiquidGlassTheme.accentBlue,
                                  )
                                : Icon(
                                    isPlaying
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    size: 19,
                                    color: isMe ? Colors.white : LiquidGlassTheme.accentBlue,
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Waveform Visualizer & scrubber
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) {
                                if (isPending) return;
                                final width = constraints.maxWidth;
                                final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                                if (!isActive) {
                                  player.playOrPause(
                                    messageId: messageId,
                                    audioUrl: audioUrl,
                                    initialDuration: totalDuration,
                                  ).then((_) => player.seekFraction(fraction));
                                } else {
                                  player.seekFraction(fraction);
                                }
                              },
                              child: SizedBox(
                                height: 28,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: List.generate(_waveformBars.length, (index) {
                                    final barHeightFactor = _waveformBars[index];
                                    final barFraction = index / _waveformBars.length;
                                    final isPlayed = barFraction <= progress;

                                    final activeColor = isMe
                                        ? Colors.white
                                        : LiquidGlassTheme.accentBlue;
                                    final inactiveColor = isMe
                                        ? Colors.white.withOpacity(0.35)
                                        : LiquidGlassTheme.textMuted.withOpacity(0.40);

                                    return Container(
                                      width: 2.4,
                                      height: (24 * barHeightFactor).clamp(4.0, 24.0),
                                      decoration: BoxDecoration(
                                        color: isPlayed ? activeColor : inactiveColor,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),

                        // Time duration and receipt
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              durationLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isMe
                                    ? Colors.white.withOpacity(0.85)
                                    : LiquidGlassTheme.textSecondary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeFormatted,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white.withOpacity(0.75)
                                        : LiquidGlassTheme.textMuted,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  if (isPending)
                                    Icon(
                                      CupertinoIcons.clock,
                                      size: 11,
                                      color: Colors.white.withOpacity(0.75),
                                    )
                                  else if (isRead)
                                    const Icon(
                                      CupertinoIcons.checkmark_alt_circle_fill,
                                      size: 11,
                                      color: Colors.white,
                                    )
                                  else
                                    Icon(
                                      CupertinoIcons.checkmark_alt,
                                      size: 11,
                                      color: Colors.white.withOpacity(0.75),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
