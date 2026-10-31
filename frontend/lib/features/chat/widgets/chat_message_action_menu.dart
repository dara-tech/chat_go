import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/user_model.dart';
import 'chat_message_bubble.dart';
import 'seen_by_hover_card.dart';

/// Full-screen focused message action menu following Telegram / iOS style and our app theme
class ChatMessageActionMenu {
  static const List<String> defaultEmojis = ['😁', '👌', '✍️', '❤️', '🙏', '😭', '👏', '🔥'];

  static Map<String, List<int>> parseReactions(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) {
      final res = <String, List<int>>{};
      raw.forEach((k, v) {
        if (v is List) {
          res[k] = v.map((e) => (e as num).toInt()).toList();
        }
      });
      return res;
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final res = <String, List<int>>{};
          decoded.forEach((k, v) {
            if (v is List) {
              res[k] = v.map((e) => (e as num).toInt()).toList();
            }
          });
          return res;
        }
      } catch (_) {}
    }
    return {};
  }

  /// Displays the full-screen focused hold message UI with reaction bar and action menu
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> msg,
    required UserModel currentUser,
    UserModel? partnerUser,
    required Function(String emoji) onReactionSelected,
    required VoidCallback onForward,
    required VoidCallback onDelete,
    VoidCallback? onReply,
    VoidCallback? onEdit,
    VoidCallback? onPin,
    VoidCallback? onSelect,
    Widget? customBubble,
  }) async {
    HapticFeedback.mediumImpact();

    final senderId = msg['sender_id'];
    final username = msg['username']?.toString();
    final isMe = msg['is_me'] == true ||
        senderId == currentUser.id ||
        (username != null && username == currentUser.username);

    final content = msg['content']?.toString() ?? '';
    final isText = content.isNotEmpty && content != 'Photo' && content != 'Audio' && content != 'Video';
    final reactionMap = parseReactions(msg['reactions']);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Menu',
      barrierColor: Colors.black.withOpacity(0.40),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secAnim) {
        return ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (ctx, _) {
            final theme = ThemeController.instance;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // 1. Emoji Reaction Bar (Capsule Pill styled to our theme)
                              _buildEmojiReactionPill(
                                context: ctx,
                                theme: theme,
                                currentUser: currentUser,
                                reactionMap: reactionMap,
                                onReactionSelected: onReactionSelected,
                              ),

                              const SizedBox(height: 6),

                              // 2. Focused Message Bubble (exact styling from our app)
                              IgnorePointer(
                                child: customBubble ??
                                    ChatMessageBubble(
                                      msg: msg,
                                      currentUser: currentUser,
                                      partnerUser: partnerUser,
                                      isDirectChat: true,
                                      onOpenImagePreview: (_) {},
                                      onOpenMediaUrl: (url, filename) {},
                                      onOpenLocationDetails: (rawLocation, [locationData]) {},
                                      onLongPressMessage: (_) {},
                                      onToggleReaction: (_) {},
                                    ),
                              ),

                              const SizedBox(height: 6),

                              // 3. Action Menu Card (aligned to bubble, following our theme)
                              _buildActionMenuCard(
                                context: ctx,
                                theme: theme,
                                msg: msg,
                                isMe: isMe,
                                isText: isText,
                                content: content,
                                partnerUser: partnerUser,
                                onReply: onReply,
                                onEdit: onEdit,
                                onPin: onPin,
                                onForward: onForward,
                                onDelete: onDelete,
                                onSelect: onSelect,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  /// Floating Capsule Pill with Emojis
  static Widget _buildEmojiReactionPill({
    required BuildContext context,
    required ThemeController theme,
    required UserModel currentUser,
    required Map<String, List<int>> reactionMap,
    required Function(String emoji) onReactionSelected,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: theme.cardBg.withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.border.withOpacity(0.7),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: defaultEmojis.map((emoji) {
              final hasReacted = reactionMap[emoji]?.contains(currentUser.id) == true;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  onReactionSelected(emoji);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasReacted
                        ? theme.primaryColor.withOpacity(0.18)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Context Action Menu Card following our theme
  static Widget _buildActionMenuCard({
    required BuildContext context,
    required ThemeController theme,
    required Map<String, dynamic> msg,
    required bool isMe,
    required bool isText,
    required String content,
    UserModel? partnerUser,
    VoidCallback? onReply,
    VoidCallback? onEdit,
    VoidCallback? onPin,
    required VoidCallback onForward,
    required VoidCallback onDelete,
    VoidCallback? onSelect,
  }) {
    final textColor = theme.textPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 176,
          decoration: BoxDecoration(
            color: theme.cardBg.withOpacity(0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.border.withOpacity(0.7),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Status Header Row (read / sent / received time / group seen)
              _buildStatusHeader(context, theme, msg, isMe, partnerUser),
              Divider(height: 0.5, thickness: 0.5, color: theme.divider.withOpacity(0.55)),

              // 2. Reply
              _buildMenuItem(
                icon: CupertinoIcons.reply,
                label: 'Reply',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  if (onReply != null) {
                    onReply();
                  } else {
                    Clipboard.setData(ClipboardData(text: content));
                  }
                },
              ),

              // 3. Copy (if message has text)
              if (isText) ...[
                _buildMenuItem(
                  icon: CupertinoIcons.doc_on_doc,
                  label: 'Copy',
                  textColor: textColor,
                  onTap: () {
                    Navigator.of(context).pop();
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: content));
                  },
                ),
              ],

              // 4. Edit (if sent message and has text)
              if (isMe && isText) ...[
                _buildMenuItem(
                  icon: CupertinoIcons.pencil,
                  label: 'Edit',
                  textColor: textColor,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (onEdit != null) onEdit();
                  },
                ),
              ],

              // 5. Pin
              _buildMenuItem(
                icon: CupertinoIcons.pin,
                label: 'Pin',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  if (onPin != null) onPin();
                },
              ),

              // 6. Forward
              _buildMenuItem(
                icon: CupertinoIcons.arrowshape_turn_up_right,
                label: 'Forward',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  onForward();
                },
              ),

              // 7. Delete (Destructive red)
              _buildMenuItem(
                icon: CupertinoIcons.trash,
                label: 'Delete',
                textColor: const Color(0xFFFF3B30),
                isDestructive: true,
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),

              // 8. Select
              Divider(height: 0.5, thickness: 0.5, color: theme.divider.withOpacity(0.55)),
              _buildMenuItem(
                icon: CupertinoIcons.checkmark_circle,
                label: 'Select',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  if (onSelect != null) {
                    onSelect();
                  } else {
                    HapticFeedback.lightImpact();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats and renders status header row with Telegram-style Seen pill, overlapping avatars & chevron
  static Widget _buildStatusHeader(
    BuildContext context,
    ThemeController theme,
    Map<String, dynamic> msg,
    bool isMe,
    UserModel? partnerUser,
  ) {
    final isGroup = msg['group_id'] != null &&
        (msg['group_id'] is num
            ? (msg['group_id'] as num) > 0
            : (int.tryParse(msg['group_id'].toString()) ?? 0) > 0);
    final isRead = msg['is_read'] == true;
    final dynamic readAt = msg['read_at'];
    final dynamic timestamp = msg['timestamp'] ?? msg['created_at'];

    // Extract seen users
    final rawSeenBy = msg['seen_by'];
    List<Map<String, dynamic>> seenByList = [];
    if (rawSeenBy is List) {
      seenByList = rawSeenBy.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final rawSeenCount = msg['seen_count'];
    int seenCount = rawSeenCount is int
        ? rawSeenCount
        : int.tryParse(rawSeenCount?.toString() ?? '') ?? seenByList.length;

    // For 1-on-1 direct chat if read and partnerUser provided, add partnerUser to seenBy if empty
    if (!isGroup && isRead && partnerUser != null && seenByList.isEmpty) {
      seenByList.add({
        'user_id': partnerUser.id,
        'username': partnerUser.username,
        'display_name': partnerUser.displayName,
        'avatar_url': partnerUser.avatarUrl,
        'read_at': readAt?.toString(),
      });
      seenCount = 1;
    }

    DateTime? time;
    if (readAt != null) {
      time = readAt is DateTime ? readAt.toLocal() : DateTime.tryParse(readAt.toString())?.toLocal();
    }
    if (time == null && timestamp != null) {
      time = timestamp is DateTime ? timestamp.toLocal() : DateTime.tryParse(timestamp.toString())?.toLocal();
    }

    final hour = time != null ? time.hour.toString().padLeft(2, '0') : '';
    final minute = time != null ? time.minute.toString().padLeft(2, '0') : '';
    final timeStr = (hour.isNotEmpty && minute.isNotEmpty) ? '$hour:$minute' : '';

    String statusText;
    IconData statusIcon;
    Color iconColor;

    if (isGroup) {
      if (seenCount > 0) {
        statusIcon = Icons.done_all;
        iconColor = const Color(0xFF67E8F9); // Electric cyan double check
        statusText = '$seenCount Seen';
      } else {
        statusIcon = Icons.done;
        iconColor = theme.textSecondary;
        statusText = 'Not seen yet';
      }
    } else {
      if (isMe) {
        if (isRead) {
          statusIcon = Icons.done_all;
          iconColor = const Color(0xFF67E8F9);
          statusText = timeStr.isNotEmpty ? 'read today at $timeStr' : 'read';
        } else {
          statusIcon = Icons.done;
          iconColor = theme.textSecondary;
          statusText = timeStr.isNotEmpty ? 'sent at $timeStr' : 'sent';
        }
      } else {
        statusIcon = CupertinoIcons.arrow_down_left;
        iconColor = theme.textSecondary;
        statusText = timeStr.isNotEmpty ? 'received at $timeStr' : 'received';
      }
    }

    final canViewSeenList = isGroup && (seenCount > 0 || seenByList.isNotEmpty || isMe);

    final groupId = msg['group_id'] is int
        ? msg['group_id'] as int
        : int.tryParse(msg['group_id']?.toString() ?? '') ?? 0;
    final messageId = msg['id'] is int
        ? msg['id'] as int
        : int.tryParse(msg['id']?.toString() ?? '') ?? 0;

    final headerRow = Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Icon(
                statusIcon,
                size: 14.5,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                style: GoogleFonts.inter(
                  fontSize: 12.8,
                  fontWeight: (isGroup && seenCount > 0) ? FontWeight.w600 : FontWeight.w400,
                  color: (isGroup && seenCount > 0) ? theme.textPrimary : theme.textSecondary,
                  letterSpacing: -0.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (seenByList.isNotEmpty) ...[
              const SizedBox(width: 5),
              _buildOverlappingAvatars(seenByList, theme),
            ],
            if (canViewSeenList) ...[
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 11.5,
                color: theme.textSecondary.withOpacity(0.7),
              ),
            ],
          ],
        ),
      ),
    );

    if (canViewSeenList) {
      return SeenHoverTarget(
        groupId: groupId,
        messageId: messageId,
        seenByList: seenByList,
        seenCount: seenCount,
        preferSide: true,
        child: headerRow,
      );
    }
    return headerRow;
  }

  /// Builds stacked circular avatars with white/dark outer borders matching Telegram
  static Widget _buildOverlappingAvatars(List<Map<String, dynamic>> users, ThemeController theme) {
    final displayUsers = users.take(3).toList();
    if (displayUsers.isEmpty) return const SizedBox.shrink();

    const double avatarSize = 18.0;
    const double overlapOffset = 10.5;
    final totalWidth = avatarSize + (displayUsers.length - 1) * overlapOffset;

    return SizedBox(
      height: avatarSize,
      width: totalWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < displayUsers.length; i++)
            Positioned(
              left: i * overlapOffset,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.isDark ? const Color(0xFF1E293B) : Colors.white,
                    width: 1.2,
                  ),
                ),
                child: ClipOval(
                  child: (displayUsers[i]['avatar_url'] != null &&
                          displayUsers[i]['avatar_url'].toString().trim().isNotEmpty)
                      ? Image.network(
                          ApiClient.resolveAvatarUrl(displayUsers[i]['avatar_url'].toString()),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(displayUsers[i]),
                        )
                      : _buildAvatarFallback(displayUsers[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildAvatarFallback(Map<String, dynamic> user) {
    final name = (user['display_name'] ?? user['username'] ?? 'U').toString().trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: const Color(0xFF6366F1),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.outfit(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  static Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color textColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Icon(
                icon,
                size: 15.5,
                color: isDestructive ? const Color(0xFFFF3B30) : textColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w400,
                  color: isDestructive ? const Color(0xFFFF3B30) : textColor,
                  letterSpacing: -0.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatReactionChips extends StatelessWidget {
  final Map<String, dynamic> msg;
  final Map<String, List<int>> reactionMap;
  final UserModel currentUser;
  final UserModel? partnerUser;
  final bool isMe;
  final Function(String emoji) onToggleReaction;
  final WrapAlignment? alignment;

  const ChatReactionChips({
    super.key,
    required this.msg,
    required this.reactionMap,
    required this.currentUser,
    this.partnerUser,
    required this.isMe,
    required this.onToggleReaction,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final effectiveAlignment = alignment ?? (isMe ? WrapAlignment.end : WrapAlignment.start);

    return Wrap(
      alignment: effectiveAlignment,
      spacing: 4,
      runSpacing: 2,
      children: reactionMap.entries.map((entry) {
        final emoji = entry.key;
        final count = entry.value.length;
        final hasReacted = entry.value.contains(currentUser.id);

        // Collect all reactors for this emoji
        final reactors = <_ReactorInfo>[];
        for (final uid in entry.value) {
          String? avatar;
          String name = '';
          if (uid == currentUser.id) {
            avatar = currentUser.avatarUrl;
            name = currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.username;
          } else if (partnerUser != null && uid == partnerUser!.id) {
            avatar = partnerUser!.avatarUrl;
            name = partnerUser!.displayName.isNotEmpty ? partnerUser!.displayName : partnerUser!.username;
          } else if (msg['sender_id'] == uid) {
            avatar = (msg['sender_avatar'] as String?)?.trim();
            name = (msg['username'] as String?) ?? '';
          }
          reactors.add(_ReactorInfo(userId: uid, avatarUrl: avatar, name: name));
        }

        final displayReactors = reactors.take(3).toList();
        final showStack = displayReactors.isNotEmpty;

        final pillColor = isMe
            ? (hasReacted
                ? Colors.white.withOpacity(0.32)
                : Colors.white.withOpacity(0.18))
            : (hasReacted
                ? theme.current.primary
                : (LiquidGlassTheme.isDark ? const Color(0xFF1E293B) : LiquidGlassTheme.bgCard));

        return GestureDetector(
          onTap: () => onToggleReaction(emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isMe
                    ? (hasReacted
                        ? Colors.white.withOpacity(0.48)
                        : Colors.white.withOpacity(0.28))
                    : (hasReacted
                        ? theme.current.primary
                        : (LiquidGlassTheme.isDark ? Colors.white.withOpacity(0.12) : LiquidGlassTheme.borderSubtle)),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
                if (showStack) ...[
                  const SizedBox(width: 4.5),
                  _buildAvatarStack(displayReactors, theme, pillColor),
                ],
                if (count > displayReactors.length) ...[
                  const SizedBox(width: 3.5),
                  Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isMe
                          ? Colors.white
                          : (hasReacted ? Colors.white : LiquidGlassTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static Widget _buildAvatarStack(
    List<_ReactorInfo> reactors,
    ThemeController theme,
    Color pillColor,
  ) {
    final displayCount = reactors.length;
    if (displayCount == 0) return const SizedBox.shrink();

    const double size = 17.5;
    const double overlap = 9.5;
    final double totalWidth = size + (displayCount - 1) * overlap;

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Render in reverse so first avatar is on top of second avatar
          for (int i = displayCount - 1; i >= 0; i--)
            Positioned(
              left: i * overlap,
              top: 0,
              child: Container(
                width: size,
                height: size,
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: pillColor,
                    width: 1.3,
                  ),
                ),
                child: ClipOval(
                  child: reactors[i].avatarUrl != null && reactors[i].avatarUrl!.isNotEmpty
                      ? Image.network(
                          ApiClient.resolveAvatarUrl(reactors[i].avatarUrl!),
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) =>
                              _buildFallbackAvatar(reactors[i].name, theme, size),
                        )
                      : _buildFallbackAvatar(reactors[i].name, theme, size),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildFallbackAvatar(String name, ThemeController theme, double size) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: theme.current.primary.withOpacity(0.35),
        child: Center(
          child: Icon(
            CupertinoIcons.person_fill,
            size: size * 0.58,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      );
    }
    final initial = trimmed[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      color: theme.current.primary.withOpacity(0.35),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ReactorInfo {
  final int userId;
  final String? avatarUrl;
  final String name;

  const _ReactorInfo({
    required this.userId,
    this.avatarUrl,
    required this.name,
  });
}


