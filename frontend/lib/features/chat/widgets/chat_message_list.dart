import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/user_model.dart';
import 'chat_message_bubble.dart';
import 'chat_typing_bubble.dart';

class ChatMessageList extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> messages;
  final bool isLoadingOlder;
  final UserModel currentUser;
  final UserModel? partnerUser;
  final bool isDirectChat;
  final Function(String imageUrl) onOpenImagePreview;
  final Function(String url, String filename) onOpenMediaUrl;
  final Function(String rawContent, [Map<String, dynamic>? msg]) onOpenLocationDetails;
  final Function(Map<String, dynamic> msg) onLongPressMessage;
  final Function(Map<String, dynamic> msg, String emoji) onToggleReaction;
  final Function(List<String> imageUrls, int initialIndex)? onOpenAlbumPreview;
  final Function(Map<String, dynamic> msg, int attachmentIndex)? onRetryAttachment;
  final bool isSelectionMode;
  final Set<int> selectedMessageIds;
  final Function(Map<String, dynamic> msg)? onToggleSelectMessage;
  final String? chatTitle;

  const ChatMessageList({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.isLoadingOlder,
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
    this.isPartnerTyping = false,
    this.isSelectionMode = false,
    this.selectedMessageIds = const {},
    this.onToggleSelectMessage,
    this.chatTitle,
  });

  final bool isPartnerTyping;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isPartnerTyping) {
      return _buildEmptyState();
    }

    final theme = ThemeController.instance;
    final accent = theme.current;
    final totalCount = messages.length + (isLoadingOlder ? 1 : 0) + (isPartnerTyping ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (isPartnerTyping && index == 0) {
          return ChatTypingBubble(partnerUser: partnerUser);
        }

        final msgIndex = isPartnerTyping ? index - 1 : index;

        if (msgIndex == messages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accent.primary),
                ),
              ),
            ),
          );
        }

        final msg = messages[msgIndex];
        final id = msg['id'] is int ? msg['id'] as int : int.tryParse(msg['id']?.toString() ?? '') ?? 0;
        final isSelected = selectedMessageIds.contains(id);

        final bubble = ChatMessageBubble(
          msg: msg,
          currentUser: currentUser,
          partnerUser: partnerUser,
          isDirectChat: isDirectChat,
          isSelectionMode: isSelectionMode,
          isSelected: isSelected,
          onToggleSelect: onToggleSelectMessage,
          onOpenImagePreview: onOpenImagePreview,
          onOpenMediaUrl: onOpenMediaUrl,
          onOpenLocationDetails: onOpenLocationDetails,
          onLongPressMessage: onLongPressMessage,
          onToggleReaction: (emoji) => onToggleReaction(msg, emoji),
          onOpenAlbumPreview: onOpenAlbumPreview,
          onRetryAttachment: onRetryAttachment,
        );

        // Date separator logic:
        // In a reverse: true list, msgIndex + 1 is the older message above msgIndex.
        // We show a date separator above msgIndex if it is the oldest message (msgIndex == messages.length - 1)
        // or if it was sent on a different calendar day than the older message above it.
        final currentDate = _parseDateTime(msg['timestamp'] ?? msg['created_at'] ?? msg['createdAt']);
        bool showDateSeparator = false;

        if (currentDate != null) {
          if (msgIndex == messages.length - 1) {
            showDateSeparator = true;
          } else {
            final olderMsg = messages[msgIndex + 1];
            final olderDate = _parseDateTime(olderMsg['timestamp'] ?? olderMsg['created_at'] ?? olderMsg['createdAt']);
            if (olderDate == null || !_isSameDay(currentDate, olderDate)) {
              showDateSeparator = true;
            }
          }
        }

        if (showDateSeparator && currentDate != null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDateSeparator(theme, currentDate),
              bubble,
            ],
          );
        }

        return bubble;
      },
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val.toLocal();
    if (val is int) {
      if (val < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(val * 1000).toLocal();
      }
      return DateTime.fromMillisecondsSinceEpoch(val).toLocal();
    }
    try {
      return DateTime.parse(val.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);

    if (msgDay == today) {
      return 'Today';
    } else if (msgDay == yesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      const weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
      ];
      final monthName = months[dt.month - 1];
      final weekdayName = weekdays[dt.weekday - 1];

      if (dt.year == now.year) {
        return '$weekdayName, $monthName ${dt.day}';
      } else {
        return '$monthName ${dt.day}, ${dt.year}';
      }
    }
  }

  Widget _buildDateSeparator(ThemeController theme, DateTime dt) {
    final isDark = theme.isDark;
    final formatted = _formatDate(dt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.6,
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : theme.border.withOpacity(0.55),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xBF1E293B) : const Color(0xD9FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.12)
                      : theme.border.withOpacity(0.6),
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                formatted,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.6,
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : theme.border.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: LiquidGlassTheme.bgCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: LiquidGlassTheme.borderSubtle,
                width: 1.0,
              ),
            ),
            child: Icon(
              CupertinoIcons.chat_bubble_2,
              size: 32,
              color: LiquidGlassTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isDirectChat
                ? 'No messages yet'
                : (chatTitle != null && chatTitle!.isNotEmpty
                    ? 'Welcome to $chatTitle!'
                    : 'No messages yet'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: LiquidGlassTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isDirectChat
                ? 'Send a friendly wave or say hi 👋'
                : 'Send the first message to start the conversation.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: LiquidGlassTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
