import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/media_download_service.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/chat_message.dart';
import '../../../models/user_model.dart';
import '../../../widgets/chat_bubble_painter.dart';
import '../../../widgets/voice_message_bubble.dart';
import '../../profile/screens/user_profile_screen.dart';
import 'chat_album_grid.dart';
import 'chat_message_action_menu.dart';
import 'chat_multi_file_card.dart';
import 'seen_by_hover_card.dart';
import 'location_message_bubble.dart';
import '../expressions/expression_models.dart';
import '../expressions/expression_registry.dart';
import '../expressions/widgets/animated_emoji_widget.dart';
import '../expressions/widgets/animated_sticker_widget.dart';

class ChatMessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final UserModel currentUser;
  final UserModel? partnerUser;
  final bool isDirectChat;
  final Function(String imageUrl) onOpenImagePreview;
  final Function(String url, String filename) onOpenMediaUrl;
  final Function(String rawContent, [Map<String, dynamic>? msg]) onOpenLocationDetails;
  final Function(Map<String, dynamic> msg) onLongPressMessage;
  final Function(String emoji) onToggleReaction;
  final Function(List<String> imageUrls, int initialIndex)? onOpenAlbumPreview;
  final Function(Map<String, dynamic> msg, int attachmentIndex)? onRetryAttachment;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(Map<String, dynamic> msg)? onToggleSelect;

  const ChatMessageBubble({
    super.key,
    required this.msg,
    required this.currentUser,
    required this.partnerUser,
    required this.isDirectChat,
    required this.onOpenImagePreview,
    required this.onOpenMediaUrl,
    required this.onOpenLocationDetails,
    required this.onLongPressMessage,
    required this.onToggleReaction,
    this.onOpenAlbumPreview,
    this.onRetryAttachment,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  static String formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime dt;
      if (timestamp is DateTime) {
        dt = timestamp;
      } else {
        dt = DateTime.parse(timestamp.toString()).toLocal();
      }
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  static IconData getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return CupertinoIcons.doc_fill;
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return CupertinoIcons.archivebox_fill;
    if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.m4a')) {
      return CupertinoIcons.music_note_2;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return CupertinoIcons.film_fill;
    return CupertinoIcons.doc_text_fill;
  }

  @override
  Widget build(BuildContext context) {
    final type = msg['type'] ?? 'chat_message';
    final sender = msg['username'] ?? 'User';
    final content = msg['content'] ?? '';
    final mediaType = msg['media_type'] ?? 'text';
    final mediaUrl = msg['media_url'] as String?;
    final rawSeenCount = msg['seen_count'];
    final int seenCount = rawSeenCount is int ? rawSeenCount : int.tryParse(rawSeenCount?.toString() ?? '') ?? 0;
    final isRead = msg['is_read'] == true || seenCount > 0 || (msg['seen_by'] is List && (msg['seen_by'] as List).isNotEmpty);
    final senderId = msg['sender_id'];
    final isMe = senderId == currentUser.id || sender == currentUser.username;

    // Presence Notification
    if (type == 'user_status') {
      final isOnline = msg['payload']?['is_online'] == true;
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.70),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.85),
              width: 1,
            ),
          ),
          child: Text(
            isOnline ? '⚡ $sender is online' : '👋 $sender left',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: LiquidGlassTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    final rawAttachments = msg['attachments'];
    List<Map<String, dynamic>> attachmentsList = [];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        if (item is Map) {
          attachmentsList.add(Map<String, dynamic>.from(item));
        } else if (item is MessageAttachment) {
          attachmentsList.add(item.toJson());
        }
      }
    }

    final isAlbum = (mediaType == 'album' ||
        (attachmentsList.length > 1 &&
            attachmentsList.every((a) {
              final t = (a['media_type'] ?? '').toString();
              return t == 'image' || t == 'photo' || t == 'video';
            })));

    final isMultiFile = (mediaType == 'mixed' ||
        (attachmentsList.length > 1 &&
            attachmentsList.any((a) {
              final t = (a['media_type'] ?? '').toString();
              return t == 'document' || t == 'file';
            })));

    final isSingleImageAttachment = !isAlbum &&
        attachmentsList.length == 1 &&
        (attachmentsList.first['media_type'] == 'image' || attachmentsList.first['media_type'] == 'photo');

    final effectiveImageUrl = (mediaUrl != null && mediaUrl.isNotEmpty)
        ? mediaUrl
        : (isSingleImageAttachment ? attachmentsList.first['url']?.toString() : null);

    final isImage = (mediaType == 'image' || isSingleImageAttachment) &&
        effectiveImageUrl != null &&
        effectiveImageUrl.isNotEmpty;

    final isSingleFileAttachment = !isMultiFile &&
        attachmentsList.length == 1 &&
        (attachmentsList.first['media_type'] == 'document' || attachmentsList.first['media_type'] == 'file');

    final effectiveFileUrl = (mediaUrl != null && mediaUrl.isNotEmpty)
        ? mediaUrl
        : (isSingleFileAttachment ? attachmentsList.first['url']?.toString() : null);

    final isFile = (mediaType == 'file' || mediaType == 'document' || isSingleFileAttachment) &&
        effectiveFileUrl != null &&
        effectiveFileUrl.isNotEmpty;
    final isLocation = mediaType == 'location' || content.contains('📍');
    final isVoice = (mediaType == 'voice' || mediaType == 'audio') && mediaUrl != null && mediaUrl.isNotEmpty;
    final isSticker = mediaType == 'sticker' && mediaUrl != null && mediaUrl.isNotEmpty;
    final isAnimatedEmoji = mediaType == 'animated_emoji' && mediaUrl != null && mediaUrl.isNotEmpty;

    // Detect animated emoji either by mediaType == 'animated_emoji' or by standalone emoji content
    final trimmedContent = content.trim();
    AnimatedEmojiItem? matchedAnimEmoji;
    if (isAnimatedEmoji) {
      for (final e in ExpressionRegistry.animatedEmojis) {
        if (e.lottieUrl == mediaUrl || e.unicodeFallback == content) {
          matchedAnimEmoji = e;
          break;
        }
      }
      matchedAnimEmoji ??= AnimatedEmojiItem(
        id: 'msg_anim_emoji_${msg['id']}',
        name: 'Emoji',
        lottieUrl: mediaUrl,
        animatedWebpUrl: msg['media_url_webp']?.toString() ?? '',
        unicodeFallback: content.isNotEmpty ? content : '😀',
      );
    } else if (!isImage && !isFile && !isVoice && !isSticker && !isLocation) { // Standalone emoji text detection
      for (final e in ExpressionRegistry.animatedEmojis) {
        if (e.unicodeFallback == trimmedContent) {
          matchedAnimEmoji = e;
          break;
        }
      }
    }

    final bubbleColumn = Builder(
      builder: (context) {
        final bubbleStyle = ThemeController.instance.bubbleStyle;
        final bubbleColor = isMe ? LiquidGlassTheme.accentBlue : LiquidGlassTheme.bgCard;
        final borderColor = isMe ? null : LiquidGlassTheme.borderSubtle;
        final forwardFrom = msg['forward_from']?.toString() ?? '';
        final hasCaption = content.isNotEmpty && content != 'Photo' && content != 'File';
        final reactionMap = ChatMessageActionMenu.parseReactions(msg['reactions']);

                final bubbleContent = _buildBubbleContent(
                  context,
                  isMe: isMe,
                  sender: sender,
                  content: content,
                  forwardFrom: forwardFrom,
                  isImage: isImage,
                  hasCaption: hasCaption,
                  mediaUrl: effectiveImageUrl ?? effectiveFileUrl,
                  isFile: isFile,
                  isLocation: isLocation,
                  isRead: isRead,
                  reactionMap: reactionMap,
                );

                Widget bubbleWidget;
                if (isAlbum && attachmentsList.length > 1) {
                  bubbleWidget = ChatAlbumGrid(
                    attachments: attachmentsList,
                    isMe: isMe,
                    isRead: isRead,
                    caption: content,
                    timestamp: msg['timestamp'],
                    sender: sender,
                    isDirectChat: isDirectChat,
                    msg: msg,
                    reactionMap: reactionMap,
                    currentUser: currentUser,
                    partnerUser: partnerUser,
                    onToggleReaction: onToggleReaction,
                    onTapImage: (idx) {
                      final urls = attachmentsList
                          .map((a) => (a['url'] ?? a['media_url'] ?? '').toString())
                          .where((u) => u.isNotEmpty)
                          .toList();
                      if (onOpenAlbumPreview != null && urls.isNotEmpty) {
                        onOpenAlbumPreview!(urls, idx);
                      } else if (idx < urls.length) {
                        onOpenImagePreview(urls[idx]);
                      }
                    },
                    onRetry: (idx) => onRetryAttachment?.call(msg, idx),
                  );
                } else if (attachmentsList.isNotEmpty &&
                    (isMultiFile ||
                        attachmentsList.any((a) =>
                            a['media_type'] == 'document' ||
                            a['media_type'] == 'file' ||
                            a['media_type'] == 'video' ||
                            a['media_type'] == 'audio'))) {
                  final card = ChatMultiFileCard(
                    attachments: attachmentsList,
                    isMe: isMe,
                    isRead: isRead,
                    caption: content,
                    timestamp: msg['timestamp'],
                    onOpenFile: onOpenMediaUrl,
                    onRetry: (idx) => onRetryAttachment?.call(msg, idx),
                  );
                  if (reactionMap.isNotEmpty) {
                    bubbleWidget = Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        card,
                        const SizedBox(height: 4),
                        ChatReactionChips(
                          msg: msg,
                          reactionMap: reactionMap,
                          currentUser: currentUser,
                          partnerUser: partnerUser,
                          isMe: isMe,
                          onToggleReaction: onToggleReaction,
                          alignment: WrapAlignment.start,
                        ),
                      ],
                    );
                  } else {
                    bubbleWidget = card;
                  }
                } else if (isImage) {
                  bubbleWidget = _buildImageBubble(
                    context,
                    mediaUrl: effectiveImageUrl,
                    forwardFrom: forwardFrom,
                    isMe: isMe,
                    isRead: isRead,
                    content: content,
                    hasCaption: hasCaption,
                    sender: sender,
                    reactionMap: reactionMap,
                  );
                } else if (isLocation) {
                  final loc = _buildLocationBubble(context, content, forwardFrom, isMe, isRead, sender);
                  if (reactionMap.isNotEmpty) {
                    bubbleWidget = Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        loc,
                        const SizedBox(height: 4),
                        ChatReactionChips(
                          msg: msg,
                          reactionMap: reactionMap,
                          currentUser: currentUser,
                          partnerUser: partnerUser,
                          isMe: isMe,
                          onToggleReaction: onToggleReaction,
                          alignment: WrapAlignment.start,
                        ),
                      ],
                    );
                  } else {
                    bubbleWidget = loc;
                  }
                } else if (isSticker) {
                  bubbleWidget = _buildStickerBubble(
                    context,
                    mediaUrl: mediaUrl,
                    isMe: isMe,
                    isRead: isRead,
                    reactionMap: reactionMap,
                  );
                } else if (matchedAnimEmoji != null) {
                  bubbleWidget = _buildAnimatedEmojiBubble(
                    context,
                    emoji: matchedAnimEmoji,
                    isMe: isMe,
                    isRead: isRead,
                    reactionMap: reactionMap,
                  );
                } else if (isVoice) {
                  bubbleWidget = Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: bubbleStyle.getBorderRadius(isMe),
                      border: borderColor != null ? Border.all(color: borderColor, width: 0.8) : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VoiceMessageBubble(
                          messageId: msg['id'],
                          audioUrl: mediaUrl,
                          durationMs: (msg['duration_ms'] as num?)?.toInt(),
                          waveformJson: msg['waveform']?.toString(),
                          isMe: isMe,
                          isRead: isRead,
                          isPending: msg['is_pending'] == true,
                          timeFormatted: formatTime(msg['timestamp']),
                        ),
                        if (reactionMap.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          ChatReactionChips(
                            msg: msg,
                            reactionMap: reactionMap,
                            currentUser: currentUser,
                            partnerUser: partnerUser,
                            isMe: isMe,
                            onToggleReaction: onToggleReaction,
                            alignment: WrapAlignment.start,
                          ),
                        ],
                      ],
                    ),
                  );
                } else if (bubbleStyle.hasCurvedTail) {
                  bubbleWidget = CustomPaint(
                    painter: TelegramBubblePainter(
                      color: bubbleColor,
                      borderColor: borderColor,
                      borderWidth: 0.8,
                      isMe: isMe,
                      radius: bubbleStyle.radius,
                    ),
                    child: Container(
                      constraints: BoxConstraints(
                        minWidth: isFile ? 240.0 : 0.0,
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: EdgeInsets.fromLTRB(
                        isMe ? 13 : 13 + 7,
                        7,
                        isMe ? 13 + 7 : 13,
                        7,
                      ),
                      child: bubbleContent,
                    ),
                  );
                } else {
                  bubbleWidget = Container(
                    constraints: BoxConstraints(
                      minWidth: isFile ? 240.0 : 0.0,
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: bubbleStyle.getBorderRadius(isMe),
                      border: borderColor != null ? Border.all(color: borderColor, width: 0.8) : null,
                    ),
                    child: bubbleContent,
                  );
                }

                final showAvatar = !isMe && !isSelectionMode && ThemeController.instance.showAvatarInChat;

                final messageBubbleRow = Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showAvatar) ...[
                      _buildSenderAvatar(context, sender, isMe),
                    ],
                    Flexible(child: bubbleWidget),
                  ],
                );

                return GestureDetector(
                  onTap: isSelectionMode ? () => onToggleSelect?.call(msg) : null,
                  onLongPress: isSelectionMode ? null : () => onLongPressMessage(msg),
                  child: messageBubbleRow,
                );
              },
            );

    if (isSelectionMode) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggleSelect?.call(msg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Stack(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? ThemeController.instance.primaryColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? ThemeController.instance.primaryColor
                            : ThemeController.instance.textSecondary.withOpacity(0.50),
                        width: 1.6,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: isMe ? 0.0 : 34.0),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: bubbleColumn),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: bubbleColumn),
        ],
      ),
    );
  }

  Widget _buildSenderAvatar(BuildContext context, String sender, bool isMe) {
    final rawAvatar = (msg['sender_avatar'] as String?)?.trim() ?? '';
    final partnerAvatar = (partnerUser?.avatarUrl ?? '').trim();
    final avatarToUse = rawAvatar.isNotEmpty
        ? rawAvatar
        : (isDirectChat ? partnerAvatar : '');
    final resolvedAvatar = ApiClient.resolveAvatarUrl(avatarToUse);

    return GestureDetector(
      onTap: () {
        final senderId = msg['sender_id'] is int
            ? msg['sender_id'] as int
            : int.tryParse(msg['sender_id']?.toString() ?? '') ?? partnerUser?.id ?? 0;
        if (senderId > 0) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => UserProfileScreen(
                userId: senderId,
                initialUser: partnerUser?.id == senderId ? partnerUser : null,
                currentUser: currentUser,
                fromChatScreen: true,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(right: 8, bottom: 2),
        decoration: BoxDecoration(
          color: LiquidGlassTheme.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 1),
        ),
        child: resolvedAvatar.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  resolvedAvatar,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LiquidGlassTheme.accentBlue,
                      ),
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlassTheme.accentBlue,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBubbleContent(
    BuildContext context, {
    required bool isMe,
    required String sender,
    required String content,
    required String forwardFrom,
    required bool isImage,
    required bool hasCaption,
    required String? mediaUrl,
    required bool isFile,
    required bool isLocation,
    required bool isRead,
    required Map<String, List<int>> reactionMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (forwardFrom.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.arrowshape_turn_up_right_fill,
                  size: 11,
                  color: isMe ? Colors.white.withOpacity(0.85) : LiquidGlassTheme.accentBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  'Forwarded from ',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isMe ? Colors.white.withOpacity(0.8) : LiquidGlassTheme.textMuted,
                  ),
                ),
                Flexible(
                  child: Text(
                    forwardFrom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.white : LiquidGlassTheme.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!isMe && !isDirectChat)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              sender,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: LiquidGlassTheme.accentBlue,
              ),
            ),
          ),



        // File attachment card if present
        if (isFile && mediaUrl != null) ...[
          ListenableBuilder(
            listenable: MediaDownloadService.instance,
            builder: (context, _) {
              final downloadService = MediaDownloadService.instance;
              final fileName = content.isNotEmpty ? content : 'Document';
              final downloadState = downloadService.getState(mediaUrl, filename: fileName);
              final isDownloading = downloadState.status == DownloadStatus.downloading;
              final isDownloaded = downloadService.isDownloaded(mediaUrl, filename: fileName);

              return GestureDetector(
                onTap: () {
                  if (isDownloading) return;
                  downloadService.openMedia(context, url: mediaUrl, filename: fileName);
                },
                onLongPress: () {
                  downloadService.showMediaOptionsSheet(
                    context,
                    url: mediaUrl,
                    filename: fileName,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.18)
                              : LiquidGlassTheme.accentBlue.withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          getFileIcon(content),
                          color: isMe ? Colors.white : LiquidGlassTheme.accentBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isMe ? Colors.white : LiquidGlassTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDownloading
                                  ? 'Downloading ${(downloadState.progress * 100).toInt()}%'
                                  : isDownloaded
                                      ? 'Downloaded • Tap to open'
                                      : 'Tap to download',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDownloading
                                    ? (isMe ? Colors.white : LiquidGlassTheme.accentBlue)
                                    : isDownloaded
                                        ? (isMe ? const Color(0xFF67E8F9) : LiquidGlassTheme.accentEmerald)
                                        : isMe
                                            ? Colors.white.withOpacity(0.80)
                                            : LiquidGlassTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDownloading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            value: downloadState.progress > 0.05 ? downloadState.progress : null,
                            strokeWidth: 2,
                            color: isMe ? Colors.white : LiquidGlassTheme.accentBlue,
                          ),
                        )
                      else if (isDownloaded)
                        GestureDetector(
                          onTap: () {
                            downloadService.saveAs(context, url: mediaUrl, filename: fileName);
                          },
                          child: Tooltip(
                            message: 'Save As',
                            child: Icon(
                              CupertinoIcons.arrow_down_doc,
                              size: 17,
                              color: isMe ? const Color(0xFF67E8F9) : LiquidGlassTheme.accentEmerald,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            downloadService.saveAs(context, url: mediaUrl, filename: fileName);
                          },
                          child: Tooltip(
                            message: 'Save As',
                            child: Icon(
                              CupertinoIcons.arrow_down_to_line,
                              size: 16,
                              color: isMe ? Colors.white.withOpacity(0.85) : LiquidGlassTheme.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
        ],

        // Text content and timestamp
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          runSpacing: 2,
          children: [
            if ((!isImage || content != 'Photo') && !isFile && !isLocation)
              Text(
                content,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: isMe ? Colors.white : LiquidGlassTheme.textPrimary,
                  height: 1.35,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: _buildReadStatusTarget(
                isMe: isMe,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      formatTime(msg['timestamp']),
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: isMe ? Colors.white.withOpacity(0.85) : LiquidGlassTheme.textMuted,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isRead ? const Color(0xFF67E8F9) : Colors.white.withOpacity(0.80),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        if (reactionMap.isNotEmpty) ...[
          const SizedBox(height: 5),
          ChatReactionChips(
            msg: msg,
            reactionMap: reactionMap,
            currentUser: currentUser,
            partnerUser: partnerUser,
            isMe: isMe,
            onToggleReaction: onToggleReaction,
            alignment: WrapAlignment.start,
          ),
        ],
      ],
    );
  }

  Widget _buildImageBubble(
    BuildContext context, {
    required String? mediaUrl,
    required String forwardFrom,
    required bool isMe,
    required bool isRead,
    required String content,
    required bool hasCaption,
    required String sender,
    required Map<String, List<int>> reactionMap,
  }) {
    if (mediaUrl == null || mediaUrl.isEmpty) return const SizedBox.shrink();

    final maxW = MediaQuery.of(context).size.width * 0.75;
    final resolvedUrl = ApiClient.resolveAvatarUrl(mediaUrl);
    final showFooter = hasCaption || reactionMap.isNotEmpty;
    final bubbleColor = isMe ? LiquidGlassTheme.accentBlue : LiquidGlassTheme.bgCard;

    return GestureDetector(
      onTap: () => onOpenImagePreview(mediaUrl),
      child: Container(
        constraints: BoxConstraints(
          minWidth: showFooter ? 200 : 0,
          maxWidth: maxW,
        ),
        decoration: BoxDecoration(
          color: showFooter ? bubbleColor : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: LiquidGlassTheme.isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            width: 0.8,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.2),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxW,
                        maxHeight: 380,
                      ),
                      child: Hero(
                        tag: 'hero_media_${msg['id']}_$mediaUrl',
                        child: Image.network(
                          resolvedUrl,
                          fit: BoxFit.contain, // NEVER crops! Shows complete photo at original aspect ratio
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: maxW,
                              height: 180,
                              color: LiquidGlassTheme.inputFill,
                              child: const Center(child: CupertinoActivityIndicator()),
                            );
                          },
                          errorBuilder: (ctx, error, stack) => Container(
                            width: maxW,
                            height: 140,
                            color: LiquidGlassTheme.inputFill,
                            child: Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                color: LiquidGlassTheme.textMuted,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Sender name for non-direct chats
                    if (!isMe && !isDirectChat && sender.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.60),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            sender,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF67E8F9),
                            ),
                          ),
                        ),
                      ),

                    // Forwarded chip
                    if (forwardFrom.isNotEmpty)
                      Positioned(
                        top: (!isMe && !isDirectChat && sender.isNotEmpty) ? 32 : 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.60),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.arrowshape_turn_up_right_fill,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Forwarded from $forwardFrom',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Floating timestamp when NO caption and NO reactions
                    if (!showFooter)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _buildReadStatusTarget(
                            isMe: isMe,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatTime(msg['timestamp']),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
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
                      ),
                  ],
                ),

                // Seamless caption bar when message has caption OR reactions
                if (showFooter)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    color: bubbleColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasCaption) ...[
                          Text(
                            content,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
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
                            if (reactionMap.isNotEmpty)
                              Flexible(
                                child: ChatReactionChips(
                                  msg: msg,
                                  reactionMap: reactionMap,
                                  currentUser: currentUser,
                                  partnerUser: partnerUser,
                                  isMe: isMe,
                                  onToggleReaction: onToggleReaction,
                                  alignment: WrapAlignment.start,
                                ),
                              )
                            else
                              const Spacer(),
                            const SizedBox(width: 8),
                            _buildReadStatusTarget(
                              isMe: isMe,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    formatTime(msg['timestamp']),
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w400,
                                      color: (isMe ? Colors.white : LiquidGlassTheme.textSecondary).withOpacity(0.75),
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 3),
                                    Icon(
                                      isRead ? Icons.done_all : Icons.done,
                                      size: 13,
                                      color: isRead ? const Color(0xFF67E8F9) : Colors.white.withOpacity(0.75),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBubble(
    BuildContext context,
    String content,
    String forwardFrom,
    bool isMe,
    bool isRead,
    String sender,
  ) {
    return LocationMessageBubble(
      msg: msg,
      currentUser: currentUser,
      partnerUser: partnerUser,
      onTap: () => onOpenLocationDetails(content, msg),
    );
  }

  Widget _buildStickerBubble(
    BuildContext context, {
    required String mediaUrl,
    required bool isMe,
    required bool isRead,
    required Map<String, List<int>> reactionMap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AnimatedStickerWidget(
              sticker: AnimatedStickerItem(
                id: 'msg_sticker_${msg['id']}',
                name: 'Sticker',
                webpUrl: mediaUrl,
                packId: 'pack',
                packName: 'Pack',
              ),
              size: 155,
            ),
            Positioned(
              right: 6,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildReadStatusTarget(
                  isMe: isMe,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTime(msg['timestamp']),
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: isRead ? Colors.lightBlueAccent : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (reactionMap.isNotEmpty) ...[
          const SizedBox(height: 4),
          ChatReactionChips(
            msg: msg,
            reactionMap: reactionMap,
            currentUser: currentUser,
            partnerUser: partnerUser,
            isMe: isMe,
            onToggleReaction: onToggleReaction,
            alignment: WrapAlignment.start,
          ),
        ],
      ],
    );
  }

  Widget _buildAnimatedEmojiBubble(
    BuildContext context, {
    required AnimatedEmojiItem emoji,
    required bool isMe,
    required bool isRead,
    required Map<String, List<int>> reactionMap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 4),
              child: AnimatedEmojiWidget(
                emoji: emoji,
                size: 96,
                repeat: true,
              ),
            ),
            Positioned(
              right: 2,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildReadStatusTarget(
                  isMe: isMe,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTime(msg['timestamp']),
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: isRead ? Colors.lightBlueAccent : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (reactionMap.isNotEmpty) ...[
          const SizedBox(height: 4),
          ChatReactionChips(
            msg: msg,
            reactionMap: reactionMap,
            currentUser: currentUser,
            partnerUser: partnerUser,
            isMe: isMe,
            onToggleReaction: onToggleReaction,
            alignment: WrapAlignment.start,
          ),
        ],
      ],
    );
  }

  Widget _buildReadStatusTarget({
    required Widget child,
    required bool isMe,
  }) {
    if (!isMe) return child;
    final isGroup = msg['group_id'] != null &&
        (msg['group_id'] is num
            ? (msg['group_id'] as num) > 0
            : (int.tryParse(msg['group_id'].toString()) ?? 0) > 0);
    if (!isGroup) return child;

    final rawSeenBy = msg['seen_by'];
    List<Map<String, dynamic>> seenByList = [];
    if (rawSeenBy is List) {
      seenByList = rawSeenBy.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final rawSeenCount = msg['seen_count'];
    final seenCount = rawSeenCount is int
        ? rawSeenCount
        : int.tryParse(rawSeenCount?.toString() ?? '') ?? seenByList.length;

    if (seenCount <= 0 && seenByList.isEmpty) return child;

    final groupId = msg['group_id'] is int
        ? msg['group_id'] as int
        : int.tryParse(msg['group_id']?.toString() ?? '') ?? 0;
    final messageId = msg['id'] is int
        ? msg['id'] as int
        : int.tryParse(msg['id']?.toString() ?? '') ?? 0;

    return SeenHoverTarget(
      groupId: groupId,
      messageId: messageId,
      seenByList: seenByList,
      seenCount: seenCount,
      preferSide: false,
      child: child,
    );
  }
}
