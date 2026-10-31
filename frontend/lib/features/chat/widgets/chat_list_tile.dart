import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../models/chat_message.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';

class ChatListTile extends StatelessWidget {
  final UserModel? user;
  final ChatGroup? group;
  final ChatConversation? conv;
  final UserModel currentUser;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ChatListTile({
    super.key,
    this.user,
    this.group,
    this.conv,
    required this.currentUser,
    required this.onTap,
    required this.onLongPress,
  });

  static String formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0 && now.day == dt.day) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    } else {
      return '${dt.month}/${dt.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (group != null) {
      final g = group!;
      final lastMsg = g.lastMessage;
      final hasConv = lastMsg != null;
      final isMe = lastMsg?.senderId == currentUser.id;
      final hasUnread = g.unreadCount > 0;
      final unreadCount = g.unreadCount;
      final timeStr = hasConv ? formatMessageTime(lastMsg.timestamp) : formatMessageTime(g.updatedAt);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Group Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: g.avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            ApiClient.resolveAvatarUrl(g.avatarUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            CupertinoIcons.person_2_fill,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Name & Message snippet
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                color: LiquidGlassTheme.textPrimary,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (timeStr.isNotEmpty)
                                Text(
                                  timeStr,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: hasUnread ? const Color(0xFFEF4444) : LiquidGlassTheme.textMuted,
                                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: hasConv
                                ? Row(
                                    children: [
                                      if (lastMsg.username.isNotEmpty && !isMe) ...[
                                        Text(
                                          '${lastMsg.username}: ',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                            color: hasUnread ? LiquidGlassTheme.textPrimary : LiquidGlassTheme.accentBlue,
                                          ),
                                        ),
                                      ] else if (isMe) ...[
                                        Text(
                                          'You: ',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: LiquidGlassTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                      Flexible(
                                        child: _buildMessagePreview(lastMsg, hasUnread),
                                      ),
                                    ],
                                  )
                                : Text(
                                    g.description.isNotEmpty ? g.description : '${g.memberCount} members',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: LiquidGlassTheme.textMuted,
                                    ),
                                  ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final u = user!;
    final hasConv = conv != null && conv!.lastMessage != null;
    final lastMsg = conv?.lastMessage;
    final isMe = lastMsg?.senderId == currentUser.id;
    final reactionsMap = lastMsg?.reactionMap ?? {};
    final activeEmojis = reactionsMap.keys.toList();

    final hasUnread = (conv?.unreadCount ?? 0) > 0;
    final unreadCount = conv?.unreadCount ?? 0;
    final timeStr = hasConv ? formatMessageTime(lastMsg!.timestamp) : (u.isOnline == true ? 'Online' : '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // User Avatar with Online Badge
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: LiquidGlassTheme.isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [LiquidGlassTheme.bgClayDim, LiquidGlassTheme.bgClayDimDarker],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: (u.avatarUrl.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(
                              ApiClient.resolveAvatarUrl(u.avatarUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: LiquidGlassTheme.accentBlue,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: LiquidGlassTheme.accentBlue,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: u.isOnline == true ? LiquidGlassTheme.accentEmerald : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(color: LiquidGlassTheme.bgScaffold, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Name & Message snippet
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            u.displayName.isNotEmpty ? u.displayName : u.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: LiquidGlassTheme.textPrimary,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (conv?.isPinned == true) ...[
                              Icon(
                                CupertinoIcons.pin_fill,
                                size: 12,
                                color: LiquidGlassTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (conv?.isMuted == true) ...[
                              Icon(
                                CupertinoIcons.bell_slash_fill,
                                size: 12,
                                color: LiquidGlassTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (hasConv && isMe) ...[
                              Icon(
                                lastMsg!.isRead ? Icons.done_all : Icons.done,
                                size: 13,
                                color: lastMsg.isRead ? LiquidGlassTheme.accentBlue : LiquidGlassTheme.textMuted,
                              ),
                              const SizedBox(width: 3),
                            ],
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: hasUnread ? LiquidGlassTheme.accentBlue : LiquidGlassTheme.textMuted,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: _buildMessagePreview(lastMsg, hasUnread),
                              ),
                              if (activeEmojis.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: LiquidGlassTheme.isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: LiquidGlassTheme.isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    activeEmojis.join(' '),
                                    style: const TextStyle(fontSize: 11, height: 1.1),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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
    );
  }

  Widget _buildMessagePreview(ChatMessage? lastMsg, bool hasUnread) {
    final textStyle = GoogleFonts.inter(
      fontSize: 12.5,
      color: hasUnread ? LiquidGlassTheme.textPrimary : LiquidGlassTheme.textSecondary,
      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
    );

    if (lastMsg == null) {
      return Text(
        '@${user?.username ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }

    final isForwarded = lastMsg.forwardFrom != null && lastMsg.forwardFrom!.isNotEmpty;

    if (lastMsg.isImage) {
      final imageUrl = lastMsg.mediaUrl ?? (lastMsg.attachments.isNotEmpty ? lastMsg.attachments.first.url : null);
      final caption = (lastMsg.content.isNotEmpty && lastMsg.content != 'Photo') ? lastMsg.content : 'Photo';
      final text = isForwarded ? 'Forwarded: $caption' : caption;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3.5),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? Image.network(
                    ApiClient.resolveAvatarUrl(imageUrl),
                    width: 17,
                    height: 17,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _buildFallbackMediaThumb(CupertinoIcons.photo),
                  )
                : _buildFallbackMediaThumb(CupertinoIcons.photo),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    if (lastMsg.isVideo) {
      final videoUrl = lastMsg.mediaUrl ?? (lastMsg.attachments.isNotEmpty ? lastMsg.attachments.first.url : null);
      final caption = (lastMsg.content.isNotEmpty && lastMsg.content != 'Video' && lastMsg.content != 'Photo')
          ? lastMsg.content
          : 'Video';
      final text = isForwarded ? 'Forwarded: $caption' : caption;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3.5),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (videoUrl != null && videoUrl.isNotEmpty)
                  Image.network(
                    ApiClient.resolveAvatarUrl(videoUrl),
                    width: 17,
                    height: 17,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _buildFallbackMediaThumb(CupertinoIcons.play_fill),
                  )
                else
                  _buildFallbackMediaThumb(CupertinoIcons.play_fill),
                Container(
                  width: 17,
                  height: 17,
                  color: Colors.black.withOpacity(0.35),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.play_fill,
                      size: 7.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    if (lastMsg.isAlbum) {
      final albumUrl = (lastMsg.attachments.isNotEmpty ? lastMsg.attachments.first.url : null) ?? lastMsg.mediaUrl;
      final caption = (lastMsg.content.isNotEmpty && lastMsg.content != 'Photo' && lastMsg.content != 'Album')
          ? lastMsg.content
          : 'Photo';
      final text = isForwarded ? 'Forwarded: $caption' : caption;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3.5),
            child: (albumUrl != null && albumUrl.isNotEmpty)
                ? Image.network(
                    ApiClient.resolveAvatarUrl(albumUrl),
                    width: 17,
                    height: 17,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _buildFallbackMediaThumb(CupertinoIcons.photo),
                  )
                : _buildFallbackMediaThumb(CupertinoIcons.photo),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    if (lastMsg.isVoice) {
      final durationStr = lastMsg.durationMs != null && lastMsg.durationMs! > 0
          ? ' (${_formatDurationMs(lastMsg.durationMs!)})'
          : '';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.mic_fill,
            size: 13,
            color: hasUnread ? LiquidGlassTheme.accentBlue : LiquidGlassTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Voice message$durationStr',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    if (lastMsg.isFile || lastMsg.isMultiFile) {
      final fileName = lastMsg.content.isNotEmpty ? lastMsg.content : 'File';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.doc_fill,
            size: 13,
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isForwarded ? 'Forwarded: $fileName' : fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    if (lastMsg.isLocation) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.location_solid,
            size: 13,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    // Default regular text
    final text = isForwarded ? 'Forwarded: ${lastMsg.content}' : lastMsg.content;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
  }

  static Widget _buildFallbackMediaThumb(IconData icon) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: LiquidGlassTheme.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(3.5),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 10,
          color: LiquidGlassTheme.textMuted,
        ),
      ),
    );
  }

  static String _formatDurationMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
