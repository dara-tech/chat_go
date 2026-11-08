import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/chat_folder_controller.dart';
import '../../../core/storage/local_chat_storage.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/chat_folder_model.dart';
import '../../../models/chat_message.dart';
import '../../../models/user_model.dart';
import 'chat_message_bubble.dart';

/// Peek & Pop Conversation Preview Modal styled with our app's actual chat UI
class ChatPreviewModal extends StatefulWidget {
  final UserModel currentUser;
  final UserModel partnerUser;
  final ChatConversation? conversation;
  final VoidCallback onOpenChat;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  const ChatPreviewModal({
    super.key,
    required this.currentUser,
    required this.partnerUser,
    required this.conversation,
    required this.onOpenChat,
    required this.onTogglePin,
    required this.onToggleMute,
    required this.onToggleRead,
    required this.onDelete,
  });

  /// Static in-memory cache for ultra-fast (0ms) instant preview rendering
  static final Map<int, List<Map<String, dynamic>>> _staticCache = {};

  /// Updates or clears static cache externally when new messages arrive
  static void updateCache(int partnerId, List<Map<String, dynamic>> messages) {
    _staticCache[partnerId] = messages;
  }

  /// Displays the preview modal with a blurred backdrop and haptic feedback
  static Future<void> show({
    required BuildContext context,
    required UserModel currentUser,
    required UserModel partnerUser,
    ChatConversation? conversation,
    required VoidCallback onOpenChat,
    required VoidCallback onTogglePin,
    required VoidCallback onToggleMute,
    required VoidCallback onToggleRead,
    required VoidCallback onDelete,
  }) async {
    HapticFeedback.mediumImpact();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Preview',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secAnim) {
        return ChatPreviewModal(
          currentUser: currentUser,
          partnerUser: partnerUser,
          conversation: conversation,
          onOpenChat: onOpenChat,
          onTogglePin: onTogglePin,
          onToggleMute: onToggleMute,
          onToggleRead: onToggleRead,
          onDelete: onDelete,
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ChatPreviewModal> createState() => _ChatPreviewModalState();
}

class _ChatPreviewModalState extends State<ChatPreviewModal> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _showFolderSubmenu = false;

  @override
  void initState() {
    super.initState();
    _initPreloadedMessages();
    _loadMessages();
  }

  /// 1. Instant (0ms) Preload: Check memory cache first, then lastMessage
  void _initPreloadedMessages() {
    final partnerId = widget.partnerUser.id;

    // Check static in-memory cache
    if (ChatPreviewModal._staticCache.containsKey(partnerId) &&
        ChatPreviewModal._staticCache[partnerId]!.isNotEmpty) {
      _messages = List<Map<String, dynamic>>.from(ChatPreviewModal._staticCache[partnerId]!);
      _isLoading = false;
      return;
    }

    // Seed from conversation's lastMessage for instant non-empty UI
    if (widget.conversation?.lastMessage != null) {
      final lm = widget.conversation!.lastMessage!;
      final m = {
        'id': lm.id,
        'sender_id': lm.senderId,
        'receiver_id': lm.receiverId,
        'username': lm.username.isNotEmpty ? lm.username : (lm.senderId == widget.currentUser.id ? widget.currentUser.username : widget.partnerUser.username),
        'content': lm.content,
        'media_type': lm.mediaType,
        'media_url': lm.mediaUrl,
        'duration_ms': lm.durationMs,
        'waveform': lm.waveform,
        'attachments': lm.attachments.map((a) => a.toJson()).toList(),
        'timestamp': lm.timestamp.toIso8601String(),
        'is_read': lm.isRead,
        'status': lm.status,
        'is_me': lm.senderId == widget.currentUser.id,
      };
      _messages = [m];
      _isLoading = false;
    }
  }

  /// 2. Concurrent Fetch: Load local disk cache then fetch fresh API messages
  Future<void> _loadMessages() async {
    final partnerId = widget.partnerUser.id;

    // A. Read local disk storage
    try {
      final diskCached = await LocalChatStorage.instance.getCachedMessages(partnerId);
      if (diskCached.isNotEmpty && mounted) {
        final normalized = _normalizeMessages(diskCached);
        if (normalized.isNotEmpty) {
          setState(() {
            _messages = normalized;
            _isLoading = false;
          });
          ChatPreviewModal._staticCache[partnerId] = normalized;
        }
      }
    } catch (_) {}

    // B. Concurrently fetch latest from backend API for consistency
    try {
      final remote = await ApiClient.instance.getMessages(partnerId, limit: 15);
      if (mounted && remote.isNotEmpty) {
        final normalized = _normalizeMessages(remote.map((m) => m.toJson()).toList());
        setState(() {
          _messages = normalized;
          _isLoading = false;
        });
        ChatPreviewModal._staticCache[partnerId] = normalized;
        LocalChatStorage.instance.saveMessages(partnerId, normalized);
      } else if (mounted && _messages.isEmpty) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted && _messages.isEmpty) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Normalizes and sorts messages in DESCENDING order (newest at index 0)
  List<Map<String, dynamic>> _normalizeMessages(List<dynamic> raw) {
    final list = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final item in raw) {
      Map<String, dynamic> m;
      if (item is ChatMessage) {
        m = item.toJson();
      } else if (item is Map) {
        m = Map<String, dynamic>.from(item);
      } else {
        continue;
      }

      final id = m['id']?.toString() ?? '';
      if (id.isNotEmpty && seen.contains(id)) continue;
      if (id.isNotEmpty) seen.add(id);

      // Ensure is_me is accurately set
      if (m['is_me'] == null) {
        final senderId = m['sender_id'];
        final username = m['username']?.toString();
        m['is_me'] = senderId == widget.currentUser.id || username == widget.currentUser.username;
      }
      list.add(m);
    }

    // Sort descending: newest first (index 0)
    list.sort((a, b) {
      final tA = a['timestamp'] is DateTime
          ? a['timestamp'] as DateTime
          : DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = b['timestamp'] is DateTime
          ? b['timestamp'] as DateTime
          : DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final isPinned = widget.conversation?.isPinned == true;
    final isMuted = widget.conversation?.isMuted == true;
    final unreadCount = widget.conversation?.unreadCount ?? 0;
    final size = MediaQuery.of(context).size;
    final previewWidth = (size.width - 28).clamp(320.0, 390.0);
    final previewHeight = (size.height * 0.54).clamp(380.0, 480.0);

    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: SizedBox(
                        width: previewWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // 1. Chat Preview Window (follows our app's real chat UI)
                            _buildChatPreviewCard(
                              context,
                              theme: theme,
                              width: previewWidth,
                              height: previewHeight,
                            ),

                            const SizedBox(height: 12),

                            // 2. Action Menu (aligned cleanly under preview card)
                            _buildActionMenu(
                              context,
                              theme: theme,
                              isPinned: isPinned,
                              isMuted: isMuted,
                              unreadCount: unreadCount,
                            ),
                          ],
                        ),
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
  }

  /// Floating Chat Preview Window with our app's theme background, actual bubbles, and Pill Header
  Widget _buildChatPreviewCard(
    BuildContext context, {
    required ThemeController theme,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        widget.onOpenChat();
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: theme.scaffoldBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: theme.border,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              // Messages List using our app's actual ChatMessageBubble with reverse: true
              Positioned.fill(
                child: _isLoading && _messages.isEmpty
                    ? Center(
                        child: CupertinoActivityIndicator(color: LiquidGlassTheme.accentBlue),
                      )
                    : _messages.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildMessagesList(theme),
              ),

              // Top Gradient Fade Overlay (so messages gracefully dissolve under the pill header)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 64,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.scaffoldBg.withOpacity(0.96),
                          theme.scaffoldBg.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Top Floating Contact Header Pill (Frosted Glass with our theme)
              Positioned(
                top: 12,
                left: 20,
                right: 20,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.cardBg.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: theme.border.withOpacity(0.7),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.partnerUser.displayName.isNotEmpty
                                  ? widget.partnerUser.displayName
                                  : widget.partnerUser.username,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              widget.partnerUser.isOnline ? 'online' : 'last seen recently',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: widget.partnerUser.isOnline
                                    ? LiquidGlassTheme.accentEmerald
                                    : theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeController theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardBg.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border, width: 0.6),
        ),
        child: Text(
          'No messages yet • Tap to chat',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: theme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Renders messages using reverse: true so newest messages are anchored at the bottom
  Widget _buildMessagesList(ThemeController theme) {
    // Show up to the latest 12 messages
    final displayList = _messages.take(12).toList();
    final totalCount = displayList.length + 1; // +1 for the top Date Badge

    return ListView.builder(
      reverse: true,
      physics: const BouncingScrollPhysics(),
      // Top padding leaves space for header pill; bottom leaves breathing room for newest message
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 70),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // Since reverse: true, the last index is at the very top of the scroll view
        if (index == displayList.length) {
          return Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12, top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.cardBg.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.border.withOpacity(0.6),
                  width: 0.6,
                ),
              ),
              child: Text(
                'Today',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
            ),
          );
        }

        final msg = displayList[index];
        return ChatMessageBubble(
          msg: msg,
          currentUser: widget.currentUser,
          partnerUser: widget.partnerUser,
          isDirectChat: true,
          onOpenImagePreview: (_) {
            Navigator.of(context).pop();
            widget.onOpenChat();
          },
          onOpenMediaUrl: (url, filename) {
            Navigator.of(context).pop();
            widget.onOpenChat();
          },
          onOpenLocationDetails: (rawLocation, [locationData]) {
            Navigator.of(context).pop();
            widget.onOpenChat();
          },
          onLongPressMessage: (_) {},
          onToggleReaction: (_) {},
        );
      },
    );
  }

  /// Context Menu matching our app's design system & Telegram mobile peek action card
  Widget _buildActionMenu(
    BuildContext context, {
    required ThemeController theme,
    required bool isPinned,
    required bool isMuted,
    required int unreadCount,
  }) {
    if (_showFolderSubmenu) {
      return _buildFolderSubmenu(context, theme: theme);
    }

    final cardBg = theme.cardBg.withOpacity(0.96);
    final textColor = theme.textPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 235,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.border,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem(
                icon: CupertinoIcons.folder_badge_plus,
                label: 'Add to Folder',
                textColor: textColor,
                hasChevron: true,
                onTap: () => setState(() => _showFolderSubmenu = true),
              ),
              Divider(height: 1, thickness: 0.5, color: theme.divider),
              _buildMenuItem(
                icon: unreadCount > 0 ? CupertinoIcons.checkmark_circle : CupertinoIcons.chat_bubble,
                label: unreadCount > 0 ? 'Mark as Read' : 'Mark as Unread',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onToggleRead();
                },
              ),
              _buildMenuItem(
                icon: isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                label: isPinned ? 'Unpin' : 'Pin to Top',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onTogglePin();
                },
              ),
              _buildMenuItem(
                icon: isMuted ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
                label: isMuted ? 'Unmute' : 'Mute',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onToggleMute();
                },
              ),
              Divider(height: 1, thickness: 0.5, color: theme.divider),
              _buildMenuItem(
                icon: CupertinoIcons.trash,
                label: 'Delete',
                textColor: const Color(0xFFFF3B30),
                isDestructive: true,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Folder submenu matching Telegram iOS peek action card (with Back row and checkmarks)
  Widget _buildFolderSubmenu(
    BuildContext context, {
    required ThemeController theme,
  }) {
    final cardBg = theme.cardBg.withOpacity(0.96);
    final textColor = theme.textPrimary;
    final controller = ChatFolderController.instance;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 235,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.border,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final folders = controller.customFolders;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back row
                  _buildMenuItem(
                    icon: CupertinoIcons.arrow_left,
                    label: 'Back',
                    textColor: textColor,
                    onTap: () => setState(() => _showFolderSubmenu = false),
                  ),
                  Divider(height: 1, thickness: 0.5, color: theme.divider),

                  if (folders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Text(
                        'No custom folders',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: theme.textSecondary,
                        ),
                      ),
                    )
                  else
                    for (int i = 0; i < folders.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 0.5, color: theme.divider),
                      () {
                        final folder = folders[i];
                        final isInFolder = controller.isChatInFolder(
                          folder.id,
                          userId: widget.partnerUser.id,
                        );
                        return _buildFolderRow(
                          folder: folder,
                          isInFolder: isInFolder,
                          theme: theme,
                          onTap: () async {
                            await controller.toggleChatInFolder(
                              folder.id,
                              userId: widget.partnerUser.id,
                            );
                          },
                        );
                      }(),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFolderRow({
    required ChatFolder folder,
    required bool isInFolder,
    required ThemeController theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              folder.iconData,
              size: 19,
              color: isInFolder ? theme.primaryColor : theme.textPrimary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isInFolder ? FontWeight.w600 : FontWeight.w500,
                  color: isInFolder ? theme.primaryColor : theme.textPrimary,
                ),
              ),
            ),
            if (isInFolder)
              Icon(
                CupertinoIcons.checkmark,
                size: 15,
                color: theme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color textColor,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool hasChevron = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: isDestructive ? const Color(0xFFFF3B30) : textColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? const Color(0xFFFF3B30) : textColor,
                ),
              ),
            ),
            if (hasChevron)
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: textColor.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}
