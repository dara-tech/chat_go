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
import '../../settings/screens/chat_folders_settings_screen.dart';

/// Top horizontal tab bar for switching between Chat Folders.
class ChatFolderTopBar extends StatelessWidget {
  final List<UserModel> users;
  final List<ChatGroup> groups;
  final Map<int, ChatConversation> convMap;
  final void Function(ChatFolder folder) onFolderSelected;
  final VoidCallback? onOpenSettings;

  const ChatFolderTopBar({
    super.key,
    required this.users,
    required this.groups,
    required this.convMap,
    required this.onFolderSelected,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChatFolderController.instance,
      builder: (context, _) {
        final controller = ChatFolderController.instance;
        final folders = controller.folders;
        final activeId = controller.activeFolderId;
        final primaryColor = ThemeController.instance.primaryColor;
        final isDark = ThemeController.instance.isDark;

        return Container(
          height: 42,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: folders.length + 1, // +1 for the edit / add folder button
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == folders.length) {
                // Manage / Add Folder Button
                return GestureDetector(
                  onTap: () {
                    if (onOpenSettings != null) {
                      onOpenSettings!();
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatFoldersSettingsScreen(
                            availableUsers: users,
                            availableGroups: groups,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.slider_horizontal_3,
                          size: 15,
                          color: LiquidGlassTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: LiquidGlassTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final folder = folders[index];
              final isSelected = folder.id == activeId;
              final unread = controller.hasUnreadInFolder(
                folder,
                users: users,
                groups: groups,
                convMap: convMap,
              );
              final count = controller.calculateCountForFolder(
                folder,
                users: users,
                groups: groups,
                convMap: convMap,
              );

              return GestureDetector(
                onTap: () {
                  controller.setActiveFolder(folder.id);
                  onFolderSelected(folder);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        folder.name,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : LiquidGlassTheme.textSecondary,
                        ),
                      ),
                      if (count > 0 || unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.24)
                                : (unread
                                    ? const Color(0xFFEF4444)
                                    : (isDark
                                        ? Colors.white.withOpacity(0.12)
                                        : Colors.black.withOpacity(0.08))),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected || unread
                                  ? Colors.white
                                  : LiquidGlassTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Left vertical icon rail for "Tabs on the left" layout.
class ChatFolderLeftRail extends StatelessWidget {
  final List<UserModel> users;
  final List<ChatGroup> groups;
  final Map<int, ChatConversation> convMap;
  final void Function(ChatFolder folder) onFolderSelected;
  final VoidCallback? onOpenSettings;

  const ChatFolderLeftRail({
    super.key,
    required this.users,
    required this.groups,
    required this.convMap,
    required this.onFolderSelected,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ChatFolderController.instance,
        ThemeController.instance,
      ]),
      builder: (context, _) {
        final controller = ChatFolderController.instance;
        final folders = controller.folders;
        final activeId = controller.activeFolderId;
        final primaryColor = ThemeController.instance.primaryColor;
        final isDark = ThemeController.instance.isDark;

        return Container(
          width: 70,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF10151E) : const Color(0xFFF1F5F9),
            border: Border(
              right: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                width: 0.8,
              ),
            ),
          ),
          child: Column(
            children: [
              // ── Traffic light dots (🔴 🟡 🟢) at top ──
              Padding(
                padding: const EdgeInsets.only(top: 14, left: 14, bottom: 16),
                child: Row(
                  children: [
                    _trafficDot(const Color(0xFFFF5F56)),
                    const SizedBox(width: 7),
                    _trafficDot(const Color(0xFFFFBD2E)),
                    const SizedBox(width: 7),
                    _trafficDot(const Color(0xFF27C93F)),
                  ],
                ),
              ),

              // ── Folders list ──
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final isSelected = folder.id == activeId;
                    final count = controller.calculateCountForFolder(
                      folder,
                      users: users,
                      groups: groups,
                      convMap: convMap,
                    );

                    return Tooltip(
                      message: folder.name,
                      child: GestureDetector(
                        onTap: () {
                          controller.setActiveFolder(folder.id);
                          onFolderSelected(folder);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    folder.id == 'all_chats'
                                        ? CupertinoIcons.chat_bubble_2_fill
                                        : folder.iconData,
                                    size: 22,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                if (count > 0)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF10151E)
                                              : Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              folder.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? primaryColor
                                    : (isDark ? Colors.white60 : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom: Sliders Manage Folders button ──
              Tooltip(
                message: 'Chat Folders Settings',
                child: IconButton(
                  icon: const Icon(CupertinoIcons.slider_horizontal_3),
                  color: isDark ? Colors.white70 : Colors.black54,
                  iconSize: 20,
                  onPressed: () {
                    if (onOpenSettings != null) {
                      onOpenSettings!();
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _trafficDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withOpacity(0.12),
          width: 0.5,
        ),
      ),
    );
  }
}
