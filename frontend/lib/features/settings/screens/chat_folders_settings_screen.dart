import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/chat_folder_controller.dart';
import '../../../core/storage/local_chat_storage.dart';
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
        backgroundColor: ThemeController.instance.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Folder',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: ThemeController.instance.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? The chats inside will not be deleted.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: ThemeController.instance.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: ThemeController.instance.textSecondary),
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
        final scaffoldBg = ThemeController.instance.scaffoldBg;
        final textPrimary = ThemeController.instance.textPrimary;
        final textSecondary = ThemeController.instance.textSecondary;
        final controller = ChatFolderController.instance;

        // Custom folders list (excluding the built-in all_chats tab)
        final folders = controller.customFolders;

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: textPrimary),
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
                color: textPrimary,
              ),
            ),
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
                          color: textSecondary,
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
                      MediaQuery.of(context).size.width >= 600
                          ? 'Drag and drop folders to change order. Right click to remove.'
                          : 'Drag and drop folders to change order. Tap to edit.',
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

                    // ── Section: TABS VIEW (Desktop only) ──
                    if (MediaQuery.of(context).size.width >= 600) ...[
                      _buildSectionHeader('TABS VIEW'),
                      _buildTabsViewCard(
                        isDark: isDark,
                        primaryColor: primaryColor,
                        controller: controller,
                      ),
                      _buildFooterCaption(
                        'If you have many folders, try moving tabs to the left.',
                      ),
                    ],
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
            color: ThemeController.instance.textSecondary,
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
            color: ThemeController.instance.textMuted,
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
    final cardBg = ThemeController.instance.cardBg;
    final borderColor = ThemeController.instance.border;
    final dividerColor = ThemeController.instance.divider;
    final textPrimary = ThemeController.instance.textPrimary;
    final textSecondary = ThemeController.instance.textSecondary;
    final textMuted = ThemeController.instance.textMuted;

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
                              // Folder Icon (matching Telegram native outline style)
                              SizedBox(
                                width: 24,
                                child: Icon(
                                  folder.iconData,
                                  color: textSecondary,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Name
                              Expanded(
                                child: Text(
                                  folder.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: textPrimary,
                                  ),
                                ),
                              ),

                              // Chat count badge
                              if (count > 0) ...[
                                Text(
                                  '$count',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],

                              // Chevron matching Telegram
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 14,
                                color: textMuted.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                        if (index < folders.length - 1)
                          Divider(
                            height: 1,
                            thickness: 0.6,
                            indent: 52,
                            color: dividerColor,
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
              thickness: 0.6,
              indent: 0,
              color: dividerColor,
            ),

          // ── "Add a Custom Folder" Row (matching Telegram native) ──
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
                    Expanded(
                      child: Text(
                        'Add a Custom Folder',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: textMuted.withOpacity(0.5),
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
      color: ThemeController.instance.cardBg,
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
              Icon(CupertinoIcons.pencil, size: 16, color: ThemeController.instance.textPrimary),
              const SizedBox(width: 10),
              Text(
                'Edit "${folder.name}"',
                style: GoogleFonts.inter(fontSize: 14, color: ThemeController.instance.textPrimary),
              ),
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
    final cardBg = ThemeController.instance.cardBg;
    final borderColor = ThemeController.instance.border;
    final textPrimary = ThemeController.instance.textPrimary;

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
              color: textPrimary,
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
    final cardBg = ThemeController.instance.cardBg;
    final borderColor = ThemeController.instance.border;

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
