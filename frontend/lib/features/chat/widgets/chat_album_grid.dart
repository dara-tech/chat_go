import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../models/user_model.dart';
import 'chat_message_action_menu.dart';

/// Renders a Telegram-style responsive collage album grid for 2 to 10+ photos/videos
class ChatAlbumGrid extends StatelessWidget {
  final List<dynamic> attachments;
  final bool isMe;
  final bool isRead;
  final String? caption;
  final dynamic timestamp;
  final String sender;
  final bool isDirectChat;
  final Function(int index) onTapImage;
  final Function(int index)? onRetry;
  final Map<String, dynamic>? msg;
  final Map<String, List<int>>? reactionMap;
  final UserModel? currentUser;
  final UserModel? partnerUser;
  final Function(String emoji)? onToggleReaction;

  const ChatAlbumGrid({
    super.key,
    required this.attachments,
    required this.isMe,
    required this.isRead,
    this.caption,
    this.timestamp,
    required this.sender,
    required this.isDirectChat,
    required this.onTapImage,
    this.onRetry,
    this.msg,
    this.reactionMap,
    this.currentUser,
    this.partnerUser,
    this.onToggleReaction,
  });

  static String formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      DateTime dt = ts is DateTime ? ts : DateTime.parse(ts.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = attachments.length;
    final maxW = MediaQuery.of(context).size.width * 0.76;
    final hasCaption = caption != null && caption!.trim().isNotEmpty && caption != 'Photo';
    final hasReactions = reactionMap != null && reactionMap!.isNotEmpty;
    final showFooter = hasCaption || hasReactions;

    final bubbleColor = isMe ? LiquidGlassTheme.accentBlue : LiquidGlassTheme.bgCard;
    final borderColor = isMe ? null : LiquidGlassTheme.borderSubtle;

    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: BoxDecoration(
        color: showFooter ? bubbleColor : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collage Grid Area
            SizedBox(
              width: maxW,
              height: _calculateGridHeight(count, maxW),
              child: _buildCollage(context, count, maxW),
            ),

            // Optional Shared Caption & Metadata footer
            if (showFooter)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasCaption) ...[
                      Text(
                        caption!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isMe ? Colors.white : LiquidGlassTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasReactions && msg != null && currentUser != null && onToggleReaction != null)
                          Flexible(
                            child: ChatReactionChips(
                              msg: msg!,
                              reactionMap: reactionMap!,
                              currentUser: currentUser!,
                              partnerUser: partnerUser,
                              isMe: isMe,
                              onToggleReaction: onToggleReaction!,
                              alignment: WrapAlignment.start,
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatTime(timestamp),
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: isMe ? Colors.white.withOpacity(0.85) : LiquidGlassTheme.textMuted,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 3),
                              Icon(
                                isRead ? Icons.done_all : Icons.done,
                                size: 13,
                                color: isRead ? const Color(0xFF67E8F9) : Colors.white.withOpacity(0.80),
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
      ),
    );
  }

  double _calculateGridHeight(int count, double width) {
    if (count == 2) return width * 0.55;
    if (count == 3) return width * 0.65;
    if (count >= 4) return width * 0.85;
    return width * 0.75;
  }

  Widget _buildCollage(BuildContext context, int count, double width) {
    if (count == 2) {
      return Row(
        children: [
          Expanded(child: _buildItemTile(0)),
          const SizedBox(width: 2),
          Expanded(child: _buildItemTile(1)),
        ],
      );
    }

    if (count == 3) {
      return Row(
        children: [
          Expanded(flex: 3, child: _buildItemTile(0)),
          const SizedBox(width: 2),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: _buildItemTile(1)),
                const SizedBox(height: 2),
                Expanded(child: _buildItemTile(2)),
              ],
            ),
          ),
        ],
      );
    }

    // 4 or more: 2x2 grid with +N on the 4th item if count > 4
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildItemTile(0)),
              const SizedBox(width: 2),
              Expanded(child: _buildItemTile(1)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildItemTile(2)),
              const SizedBox(width: 2),
              Expanded(
                child: _buildItemTile(
                  3,
                  remainingCount: count > 4 ? count - 4 : 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(int index, {int remainingCount = 0}) {
    if (index >= attachments.length) return const SizedBox.shrink();
    final raw = attachments[index];
    final map = raw is Map<String, dynamic>
        ? raw
        : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});

    final url = map['url'] ?? map['media_url'] ?? '';
    final localPath = map['local_path'] as String?;
    final localBytes = map['local_bytes'] as List<int>?;
    final isVideo = (map['media_type'] ?? '') == 'video';
    final uploadStatus = map['upload_status'] ?? 'completed';
    final progress = (map['progress'] as num?)?.toDouble() ?? 1.0;
    final isUploading = uploadStatus == 'uploading' || uploadStatus == 'pending';
    final isFailed = uploadStatus == 'failed';

    return GestureDetector(
      onTap: () {
        if (isFailed) {
          onRetry?.call(index);
        } else {
          onTapImage(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image / Video thumbnail
          _buildThumbnailImage(url, localPath, localBytes),

          // Dark overlay if +N remaining
          if (remainingCount > 0)
            Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Video indicator badge
          if (isVideo && remainingCount == 0)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 12),
              ),
            ),

          // Uploading spinner or progress overlay
          if (isUploading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: progress > 0.05 ? progress : null,
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Failed retry badge
          if (isFailed)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Retry',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Timestamp pill if no caption and no reactions, and this is the last visible tile
          if ((caption == null || caption!.trim().isEmpty || caption == 'Photo') &&
              (reactionMap == null || reactionMap!.isEmpty) &&
              (remainingCount > 0 ? index == 3 : index == attachments.length - 1))
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatTime(timestamp),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 13,
                        color: isRead ? const Color(0xFF67E8F9) : Colors.white.withOpacity(0.85),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailImage(String url, String? localPath, List<int>? localBytes) {
    if (localBytes != null && localBytes.isNotEmpty) {
      return Image.memory(
        Uint8List.fromList(localBytes),
        fit: BoxFit.cover,
      );
    }
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    if (url.isNotEmpty) {
      final resolvedUrl = ApiClient.resolveAvatarUrl(url);
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
          color: const Color(0xFF1E1E24),
          child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.white38)),
        ),
      );
    }
    return Container(
      color: const Color(0xFF1E1E24),
      child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.white38)),
    );
  }
}
