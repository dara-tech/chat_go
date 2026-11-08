import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/chat_folder_controller.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/chat_folder_model.dart';
import '../../../models/chat_message.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';

/// Desktop & Mobile context menu with hover flyout submenus (matching native Telegram macOS)
class ChatContextMenu extends StatefulWidget {
  final Offset position;
  final UserModel? user;
  final ChatGroup? group;
  final ChatConversation? conv;
  final UserModel currentUser;
  final VoidCallback onOpenChat;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleRead;
  final VoidCallback onPreview;
  final VoidCallback onDelete;
  final VoidCallback? onClearHistory;

  const ChatContextMenu({
    super.key,
    required this.position,
    this.user,
    this.group,
    this.conv,
    required this.currentUser,
    required this.onOpenChat,
    required this.onTogglePin,
    required this.onToggleMute,
    required this.onToggleRead,
    required this.onPreview,
    required this.onDelete,
    this.onClearHistory,
  });

  static Future<void> show({
    required BuildContext context,
    required Offset position,
    UserModel? user,
    ChatGroup? group,
    ChatConversation? conv,
    required UserModel currentUser,
    required VoidCallback onOpenChat,
    required VoidCallback onTogglePin,
    required VoidCallback onToggleMute,
    required VoidCallback onToggleRead,
    required VoidCallback onPreview,
    required VoidCallback onDelete,
    VoidCallback? onClearHistory,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Context Menu',
      barrierColor: Colors.transparent, // Fully transparent so context remains visible
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (ctx, anim, secAnim) {
        return ChatContextMenu(
          position: position,
          user: user,
          group: group,
          conv: conv,
          currentUser: currentUser,
          onOpenChat: onOpenChat,
          onTogglePin: onTogglePin,
          onToggleMute: onToggleMute,
          onToggleRead: onToggleRead,
          onPreview: onPreview,
          onDelete: onDelete,
          onClearHistory: onClearHistory,
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curve),
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ChatContextMenu> createState() => _ChatContextMenuState();
}

class _ChatContextMenuState extends State<ChatContextMenu> {
  String? _activeSubmenu; // 'folder' or null
  bool _showInlineFolders = false;
  final GlobalKey _addFolderKey = GlobalKey();
  double _folderItemTop = 0;

  void _updateFolderItemPosition() {
    final renderBox = _addFolderKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final boxPos = renderBox.localToGlobal(Offset.zero);
      setState(() {
        _folderItemTop = boxPos.dy;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = ThemeController.instance.isDark;
    final primaryColor = ThemeController.instance.primaryColor;

    const double menuWidth = 220;
    const double submenuWidth = 180;
    const double estimatedMenuHeight = 360;
    final bool isCompactScreen = screenSize.width < 500;

    // Calculate main menu position so it never overflows screen bounds
    double left = widget.position.dx;
    if (left + menuWidth > screenSize.width - 16) {
      left = screenSize.width - menuWidth - 16;
    }
    if (left < 16) left = 16;

    double top = widget.position.dy;
    if (top + estimatedMenuHeight > screenSize.height - 16) {
      top = screenSize.height - estimatedMenuHeight - 16;
    }
    if (top < 16) top = 16;

    // Clamped submenu position that never clips offscreen
    final bool openSubmenuOnLeft = (left + menuWidth + submenuWidth) > (screenSize.width - 16);
    double submenuLeft;
    if (openSubmenuOnLeft) {
      submenuLeft = left - submenuWidth - 4;
      if (submenuLeft < 10) {
        if (left + menuWidth + submenuWidth + 10 <= screenSize.width) {
          submenuLeft = left + menuWidth + 4;
        } else {
          submenuLeft = 10;
        }
      }
    } else {
      submenuLeft = left + menuWidth + 4;
      if (submenuLeft + submenuWidth > screenSize.width - 10) {
        if (left - submenuWidth - 4 >= 10) {
          submenuLeft = left - submenuWidth - 4;
        } else {
          submenuLeft = screenSize.width - submenuWidth - 10;
        }
      }
    }

    final isPinned = widget.conv?.isPinned ?? false;
    final isMuted = widget.conv?.isMuted ?? false;
    final unreadCount = widget.conv?.unreadCount ?? widget.group?.unreadCount ?? 0;

    final menuBg = isDark
        ? const Color(0xFF1E2430).withOpacity(0.95)
        : Colors.white.withOpacity(0.96);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.08);

    return Stack(
      children: [
        // Background dismiss tap handler
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            onSecondaryTap: () => Navigator.of(context).pop(),
          ),
        ),

        // ── Main Context Menu ──
        Positioned(
          left: left,
          top: top,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: menuWidth,
                decoration: BoxDecoration(
                  color: menuBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                child: _showInlineFolders
                    ? _buildInlineFolderMenu(context, borderColor, primaryColor)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Open In Window
                          _MenuItem(
                            icon: CupertinoIcons.arrow_up_right_square,
                            label: 'Open In Window',
                            onHover: () => setState(() => _activeSubmenu = null),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onOpenChat();
                            },
                          ),

                          // 2. Pin / Unpin
                          _MenuItem(
                            icon: isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                            label: isPinned ? 'Unpin' : 'Pin',
                            onHover: () => setState(() => _activeSubmenu = null),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onTogglePin();
                            },
                          ),

                          // 3. Mute / Unmute
                          _MenuItem(
                            icon: isMuted ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
                            label: isMuted ? 'Unmute' : 'Mute',
                            onHover: () => setState(() => _activeSubmenu = null),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onToggleMute();
                            },
                          ),

                          // 4. Mark As Read / Unread
                          _MenuItem(
                            icon: unreadCount > 0 ? CupertinoIcons.checkmark_circle : CupertinoIcons.chat_bubble,
                            label: unreadCount > 0 ? 'Mark As Read' : 'Mark As Unread',
                            onHover: () => setState(() => _activeSubmenu = null),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onToggleRead();
                            },
                          ),

                          // 5. Preview
                          _MenuItem(
                            icon: CupertinoIcons.eye,
                            label: 'Preview',
                            onHover: () => setState(() => _activeSubmenu = null),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onPreview();
                            },
                          ),

                          _divider(borderColor),

                          // 6. Add to folder... > (HOVER OPENS SUBMENU ON DESKTOP, TAP FLIPS TO INLINE ON MOBILE)
                          Container(
                            key: _addFolderKey,
                            child: _MenuItem(
                              icon: CupertinoIcons.folder_badge_plus,
                              label: 'Add to folder...',
                              hasSubmenu: true,
                              isHighlighted: _activeSubmenu == 'folder' || _showInlineFolders,
                              onHover: () {
                                if (!isCompactScreen) {
                                  _updateFolderItemPosition();
                                  setState(() => _activeSubmenu = 'folder');
                                }
                              },
                              onTap: () {
                                if (isCompactScreen) {
                                  setState(() => _showInlineFolders = true);
                                } else {
                                  _updateFolderItemPosition();
                                  setState(() {
                                    _activeSubmenu = (_activeSubmenu == 'folder') ? null : 'folder';
                                  });
                                }
                              },
                            ),
                          ),

                          // 7. Remove From Folder
                          _MenuItem(
                            icon: CupertinoIcons.folder_badge_minus,
                            label: 'Remove From Folder',
                            onHover: () => setState(() => _activeSubmenu = null),
                            onTap: () {
                              Navigator.of(context).pop();
                              _removeFromAllFolders();
                            },
                          ),

                          _divider(borderColor),

                          // 8. Clear History
                          _MenuItem(
                            icon: CupertinoIcons.trash,
                            label: 'Clear History',
                            onHover: () => setState(() => _activeSubmenu = null),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onClearHistory?.call();
                            },
                          ),

                          // 9. Delete Chat / Leave
                          _MenuItem(
                            icon: CupertinoIcons.trash,
                            label: widget.group != null ? 'Delete and Leave' : 'Delete Chat',
                            textColor: const Color(0xFFFF453A),
                            isDestructive: true,
                            onHover: () => setState(() => _activeSubmenu = null),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onDelete();
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        // ── Submenu: Floating Folder List (Opened when hovering on "Add to folder..." on desktop) ──
        if (_activeSubmenu == 'folder' && !isCompactScreen && !_showInlineFolders)
          Positioned(
            left: submenuLeft,
            top: _folderItemTop > 0 ? _folderItemTop - 4 : top + 150,
            child: _FolderSubmenu(
              user: widget.user,
              group: widget.group,
              width: submenuWidth,
              menuBg: menuBg,
              borderColor: borderColor,
              primaryColor: primaryColor,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
      ],
    );
  }

  Widget _buildInlineFolderMenu(BuildContext context, Color borderColor, Color primaryColor) {
    final controller = ChatFolderController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final folders = controller.customFolders;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuItem(
              icon: CupertinoIcons.arrow_left,
              label: 'Back',
              onTap: () => setState(() => _showInlineFolders = false),
              onHover: () {},
            ),
            _divider(borderColor),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(
                  'No custom folders',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: LiquidGlassTheme.textMuted,
                  ),
                ),
              )
            else
              ...folders.map((folder) {
                final isInFolder = controller.isChatInFolder(
                  folder.id,
                  userId: widget.user?.id,
                  groupId: widget.group?.id,
                );

                return _FolderSubmenuItem(
                  folder: folder,
                  isInFolder: isInFolder,
                  primaryColor: primaryColor,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final willBeInFolder = !isInFolder;
                    await controller.toggleChatInFolder(
                      folder.id,
                      userId: widget.user?.id,
                      groupId: widget.group?.id,
                    );

                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          willBeInFolder
                              ? 'Added to "${folder.name}"'
                              : 'Removed from "${folder.name}"',
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
          ],
        );
      },
    );
  }

  void _removeFromAllFolders() {
    final controller = ChatFolderController.instance;
    final userId = widget.user?.id;
    final groupId = widget.group?.id;

    for (final folder in controller.customFolders) {
      if (controller.isChatInFolder(folder.id, userId: userId, groupId: groupId)) {
        controller.toggleChatInFolder(folder.id, userId: userId, groupId: groupId);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Removed from all folders'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _divider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1, thickness: 0.6, color: color),
    );
  }
}

/// A single item inside the context menu with hover effect and optional submenu chevron
class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final bool hasSubmenu;
  final bool isHighlighted;
  final Color? textColor;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onHover,
    this.hasSubmenu = false,
    this.isHighlighted = false,
    this.textColor,
    this.isDestructive = false,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final primaryColor = ThemeController.instance.primaryColor;
    final effectiveHighlighted = _isHovered || widget.isHighlighted;

    final defaultText = widget.isDestructive
        ? const Color(0xFFFF453A)
        : (isDark ? Colors.white : Colors.black87);
    final color = widget.textColor ?? defaultText;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover();
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: effectiveHighlighted
                ? (isDark
                    ? primaryColor.withOpacity(0.18)
                    : primaryColor.withOpacity(0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 17, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (widget.hasSubmenu)
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 13,
                  color: color.withOpacity(0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cascading submenu showing custom folders
class _FolderSubmenu extends StatelessWidget {
  final UserModel? user;
  final ChatGroup? group;
  final double width;
  final Color menuBg;
  final Color borderColor;
  final Color primaryColor;
  final VoidCallback onClose;

  const _FolderSubmenu({
    required this.user,
    required this.group,
    required this.width,
    required this.menuBg,
    required this.borderColor,
    required this.primaryColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final controller = ChatFolderController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final folders = controller.customFolders;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: menuBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: folders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Text(
                        'No custom folders',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: LiquidGlassTheme.textMuted,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: folders.map((folder) {
                        final isInFolder = controller.isChatInFolder(
                          folder.id,
                          userId: user?.id,
                          groupId: group?.id,
                        );

                        return _FolderSubmenuItem(
                          folder: folder,
                          isInFolder: isInFolder,
                          primaryColor: primaryColor,
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final willBeInFolder = !isInFolder;
                            await controller.toggleChatInFolder(
                              folder.id,
                              userId: user?.id,
                              groupId: group?.id,
                            );

                            messenger.clearSnackBars();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  willBeInFolder
                                      ? 'Added to "${folder.name}"'
                                      : 'Removed from "${folder.name}"',
                                ),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _FolderSubmenuItem extends StatefulWidget {
  final ChatFolder folder;
  final bool isInFolder;
  final Color primaryColor;
  final VoidCallback onTap;

  const _FolderSubmenuItem({
    required this.folder,
    required this.isInFolder,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_FolderSubmenuItem> createState() => _FolderSubmenuItemState();
}

class _FolderSubmenuItemState extends State<_FolderSubmenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final primaryColor = widget.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                    ? primaryColor.withOpacity(0.20)
                    : primaryColor.withOpacity(0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.folder.iconData,
                size: 16,
                color: widget.isInFolder ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: widget.isInFolder ? FontWeight.w600 : FontWeight.w500,
                    color: widget.isInFolder ? primaryColor : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
              if (widget.isInFolder)
                Icon(
                  CupertinoIcons.checkmark,
                  size: 13,
                  color: primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
