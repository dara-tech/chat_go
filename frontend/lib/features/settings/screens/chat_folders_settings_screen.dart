import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/chat_folder_controller.dart';
import '../../../core/storage/local_chat_storage.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/chat_folder_model.dart';
import '../../../models/chat_message.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../widgets/chat_folder_graphics.dart';
import 'edit_chat_folder_screen.dart';

class ChatFoldersSettingsScreen extends StatefulWidget {
  final List<UserModel> availableUsers;
  final List<ChatGroup> availableGroups;
  final VoidCallback? onClose;

  const ChatFoldersSettingsScreen({
    super.key,
    this.availableUsers = const [],
    this.availableGroups = const [],
    this.onClose,
  });

  @override
  State<ChatFoldersSettingsScreen> createState() =>
      _ChatFoldersSettingsScreenState();
}

class _ChatFoldersSettingsScreenState extends State<ChatFoldersSettingsScreen> {
  Map<int, ChatConversation> _convMap = {};
  ChatFolder? _editingFolder;
  bool _isCreatingFolder = false;

  @override
  void initState() {
    super.initState();
    _loadConvMap();
  }

  Future<void> _loadConvMap() async {
    final list = await LocalChatStorage.instance.getCachedConversations();
    if (mounted) {
      setState(() {
        _convMap = {for (final c in list) c.user.id: c};
      });
    }
  }

  void _openAddFolder() {
    setState(() {
      _isCreatingFolder = true;
      _editingFolder = null;
    });
  }

  void _openEditFolder(ChatFolder folder) {
    setState(() {
      _editingFolder = folder;
      _isCreatingFolder = false;
    });
  }

  void _confirmDeleteFolder(ChatFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeController.instance.isDark
            ? const Color(0xFF1E2430)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Folder',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: LiquidGlassTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? The chats inside will not be deleted.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: LiquidGlassTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: LiquidGlassTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ChatFolderController.instance.deleteFolder(folder.id);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If the user tapped Add or Edit a folder, show EditChatFolderScreen embedded inside the right panel
    if (_isCreatingFolder || _editingFolder != null) {
      return EditChatFolderScreen(
        existingFolder: _editingFolder,
        availableUsers: widget.availableUsers,
        availableGroups: widget.availableGroups,
        onBack: () => setState(() {
          _isCreatingFolder = false;
          _editingFolder = null;
        }),
        onSaved: () => setState(() {
          _isCreatingFolder = false;
          _editingFolder = null;
        }),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        ChatFolderController.instance,
      ]),
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        final primaryColor = ThemeController.instance.primaryColor;
        final controller = ChatFolderController.instance;

        // Custom folders list (excluding the built-in all_chats tab)
        final folders = controller.customFolders;

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0F172A)
              : ThemeController.instance.scaffoldBg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
            centerTitle: true,
            title: Text(
              'Chat Folders',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
            actions: [
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(CupertinoIcons.clear),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

                    // ── Hero Graphic & Description ──
                    const Center(child: ChatFolderHeroGraphic(size: 88)),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Create folders for different groups of chats and quickly switch between them.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: LiquidGlassTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Section: FOLDERS ──
                    _buildSectionHeader('FOLDERS'),
                    _buildFoldersCard(
                      context: context,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      controller: controller,
                      folders: folders,
                    ),
                    _buildFooterCaption(
                      'Drag and drop folders to change order. Right click to remove.',
                    ),
                    const SizedBox(height: 24),

                    // ── Section: Show Folder Tags ──
                    _buildTagsCard(
                      isDark: isDark,
                      primaryColor: primaryColor,
                      controller: controller,
                    ),
                    _buildFooterCaption(
                      'Display folder names for each chat in the chat list.',
                    ),
                    const SizedBox(height: 24),

                    // ── Section: TABS VIEW ──
                    _buildSectionHeader('TABS VIEW'),
                    _buildTabsViewCard(
                      isDark: isDark,
                      primaryColor: primaryColor,
                      controller: controller,
                    ),
                    _buildFooterCaption(
                      'If you have many folders, try moving tabs to the left.',
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: LiquidGlassTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterCaption(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: LiquidGlassTheme.textMuted,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildFoldersCard({
    required BuildContext context,
    required bool isDark,
    required Color primaryColor,
    required ChatFolderController controller,
    required List<ChatFolder> folders,
  }) {
    final cardBg = isDark ? const Color(0xFF1E2430) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (folders.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: folders.length,
              onReorder: (oldIndex, newIndex) {
                controller.reorderFolders(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final folder = folders[index];
                final count = controller.calculateCountForFolder(
                  folder,
                  users: widget.availableUsers,
                  groups: widget.availableGroups,
                  convMap: _convMap,
                );

                return Material(
                  key: ValueKey(folder.id),
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openEditFolder(folder),
                    onSecondaryTapDown: (details) {
                      _showFolderContextMenu(context, details.globalPosition, folder);
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              // Folder Icon
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  folder.iconData,
                                  color: primaryColor,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Name
                              Expanded(
                                child: Text(
                                  folder.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: LiquidGlassTheme.textPrimary,
                                  ),
                                ),
                              ),

                              // Chat count badge
                              if (count > 0)
                                Text(
                                  '$count',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: LiquidGlassTheme.textSecondary,
                                  ),
                                ),
                              const SizedBox(width: 10),

                              // Reorder drag handle
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  CupertinoIcons.bars,
                                  color: LiquidGlassTheme.textMuted,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index < folders.length - 1)
                          Divider(
                            height: 1,
                            thickness: 0.8,
                            indent: 62,
                            color: borderColor,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

          if (folders.isNotEmpty)
            Divider(
              height: 1,
              thickness: 0.8,
              indent: 0,
              color: borderColor,
            ),

          // ── "Add a Custom Folder" Row ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openAddFolder,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CupertinoIcons.add,
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Add a Custom Folder',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 15,
                      color: LiquidGlassTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFolderContextMenu(
    BuildContext context,
    Offset position,
    ChatFolder folder,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(CupertinoIcons.pencil, size: 16),
              const SizedBox(width: 10),
              Text('Edit "${folder.name}"', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(CupertinoIcons.trash, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 10),
              Text(
                'Delete Folder',
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'edit') {
        _openEditFolder(folder);
      } else if (choice == 'delete') {
        _confirmDeleteFolder(folder);
      }
    });
  }

  Widget _buildTagsCard({
    required bool isDark,
    required Color primaryColor,
    required ChatFolderController controller,
  }) {
    final cardBg = isDark ? const Color(0xFF1E2430) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Show Folder Tags',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: LiquidGlassTheme.textPrimary,
            ),
          ),
          CupertinoSwitch(
            value: controller.showFolderTags,
            activeColor: primaryColor,
            onChanged: (val) => controller.setShowFolderTags(val),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsViewCard({
    required bool isDark,
    required Color primaryColor,
    required ChatFolderController controller,
  }) {
    final cardBg = isDark ? const Color(0xFF1E2430) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ── Top View Option ──
          TabsViewMockupCard(
            label: 'Tabs at the top',
            isSelected: controller.tabsView == 'top',
            isTabsOnLeft: false,
            onTap: () => controller.setTabsView('top'),
          ),

          // ── Left View Option ──
          TabsViewMockupCard(
            label: 'Tabs on the left',
            isSelected: controller.tabsView == 'left',
            isTabsOnLeft: true,
            onTap: () => controller.setTabsView('left'),
          ),
        ],
      ),
    );
  }
}
