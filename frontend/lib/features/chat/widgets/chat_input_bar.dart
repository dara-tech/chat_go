import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/voice/voice_service.dart';
import 'chat_voice_recorder_bar.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController messageController;
  final bool hasText;
  final bool isUploadingMedia;
  final bool isVoiceRecording;
  final bool isVoicePreviewing;
  final VoiceRecordingResult? previewRecording;
  final VoidCallback onSendMessage;
  final VoidCallback onShowAttachmentModal;
  final VoidCallback onStartVoiceRecording;
  final VoidCallback onCancelVoiceRecording;
  final VoidCallback onLockOrPreviewVoiceRecording;
  final VoidCallback onSendVoiceRecording;
  final VoidCallback? onShowExpressionPicker;

  const ChatInputBar({
    super.key,
    required this.messageController,
    required this.hasText,
    required this.isUploadingMedia,
    required this.isVoiceRecording,
    required this.isVoicePreviewing,
    required this.previewRecording,
    required this.onSendMessage,
    required this.onShowAttachmentModal,
    required this.onStartVoiceRecording,
    required this.onCancelVoiceRecording,
    required this.onLockOrPreviewVoiceRecording,
    required this.onSendVoiceRecording,
    this.onShowExpressionPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgSurface,
        border: Border(
          top: BorderSide(
            color: LiquidGlassTheme.dividerHairline,
            width: 1.0,
          ),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: isVoiceRecording || isVoicePreviewing
            ? ChatVoiceRecorderBar(
                isRecording: isVoiceRecording,
                isPreviewing: isVoicePreviewing,
                previewRecording: previewRecording,
                onCancel: onCancelVoiceRecording,
                onLockOrPreview: onLockOrPreviewVoiceRecording,
                onSend: onSendVoiceRecording,
              )
            : _buildStandardInputBar(),
      ),
    );
  }

  Widget _buildStandardInputBar() {
    return Container(
      key: const ValueKey('standard_input_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.inputFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          // File & Media Attachment button
          GestureDetector(
            onTap: isUploadingMedia ? null : onShowAttachmentModal,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.inputFill,
                shape: BoxShape.circle,
                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
              ),
              child: isUploadingMedia
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 8),
                    )
                  : Icon(
                      CupertinoIcons.paperclip,
                      size: 20,
                      color: LiquidGlassTheme.textSecondary,
                    ),
            ),
          ),
          const SizedBox(width: 8),

          // Message Input Field
          Expanded(
            child: TextField(
              controller: messageController,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: LiquidGlassTheme.textPrimary,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSendMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: LiquidGlassTheme.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          // Emoji / Sticker Picker Button
          if (onShowExpressionPicker != null) ...[
            GestureDetector(
              onTap: onShowExpressionPicker,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                  CupertinoIcons.smiley,
                  size: 23,
                  color: LiquidGlassTheme.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(width: 3),

          // Send Button or Voice Mic Button
          GestureDetector(
            onTap: hasText ? onSendMessage : onStartVoiceRecording,
            onLongPress: hasText ? null : onStartVoiceRecording,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: hasText
                    ? LiquidGlassTheme.accentBlue
                    : LiquidGlassTheme.accentBlue.withOpacity(0.90),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  hasText ? CupertinoIcons.arrow_up : CupertinoIcons.mic_fill,
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
