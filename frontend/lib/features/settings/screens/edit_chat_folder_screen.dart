import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/chat_folder_controller.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/chat_folder_model.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';

class EditChatFolderScreen extends StatefulWidget {
  final ChatFolder? existingFolder;
  final List<UserModel> availableUsers;
  final List<ChatGroup> availableGroups;

  const EditChatFolderScreen({
    super.key,
    this.existingFolder,
    this.availableUsers = const [],
    this.availableGroups = const [],
  });

  @override
  State<EditChatFolderScreen> createState() => _EditChatFolderScreenState();
}

class _EditChatFolderScreenState extends State<EditChatFolderScreen> {
  late TextEditingController _nameController;
  late String _selectedIconKey;
  late List<int> _includedUserIds;
  late List<int> _includedGroupIds;
  late List<int> _excludedUserIds;
  late List<int> _excludedGroupIds;

  late bool _includePersonal;
  late bool _includeGroups;
  late bool _includeUnreadOnly;
  late bool _excludeMuted;
  late bool _excludeRead;

  bool get isEditing => widget.existingFolder != null;

  @override
  void initState() {
    super.initState();
    final f = widget.existingFolder;
    _nameController = TextEditingController(text: f?.name ?? '');
    _selectedIconKey = f?.iconKey ?? 'folder';
    _includedUserIds = List<int>.from(f?.includedUserIds ?? []);
    _includedGroupIds = List<int>.from(f?.includedGroupIds ?? []);
    _excludedUserIds = List<int>.from(f?.excludedUserIds ?? []);
    _excludedGroupIds = List<int>.from(f?.excludedGroupIds ?? []);

    _includePersonal = f?.includePersonal ?? true;
    _includeGroups = f?.includeGroups ?? true;
    _includeUnreadOnly = f?.includeUnreadOnly ?? false;
    _excludeMuted = f?.excludeMuted ?? false;
    _excludeRead = f?.excludeRead ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );
      return;
    }

    final id = widget.existingFolder?.id ??
        'folder_${DateTime.now().millisecondsSinceEpoch}';

    final folder = ChatFolder(
      id: id,
      name: name,
      iconKey: _selectedIconKey,
      isSystem: false,
      includePersonal: _includePersonal,
      includeGroups: _includeGroups,
      includeUnreadOnly: _includeUnreadOnly,
      includedUserIds: _includedUserIds,
      includedGroupIds: _includedGroupIds,
      excludedUserIds: _excludedUserIds,
      excludedGroupIds: _excludedGroupIds,
      excludeMuted: _excludeMuted,
      excludeRead: _excludeRead,
    );

    if (isEditing) {
      ChatFolderController.instance.updateFolder(folder);
    } else {
      ChatFolderController.instance.createFolder(folder);
    }

    Navigator.of(context).pop();
  }

  void _delete() {
    if (widget.existingFolder != null) {
      ChatFolderController.instance.deleteFolder(widget.existingFolder!.id);
      Navigator.of(context).pop();
    }
  }

  void _openChatPicker({required bool isInclude}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatPickerSheet(
        users: widget.availableUsers,
        groups: widget.availableGroups,
        initiallySelectedUserIds:
            isInclude ? _includedUserIds : _excludedUserIds,
        initiallySelectedGroupIds:
            isInclude ? _includedGroupIds : _excludedGroupIds,
        onDone: (selectedUsers, selectedGroups) {
          setState(() {
            if (isInclude) {
              _includedUserIds = selectedUsers;
              _includedGroupIds = selectedGroups;
            } else {
              _excludedUserIds = selectedUsers;
              _excludedGroupIds = selectedGroups;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final primaryColor = ThemeController.instance.primaryColor;

    return Scaffold(
      backgroundColor: ThemeController.instance.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit Folder' : 'New Folder',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: LiquidGlassTheme.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              isEditing ? 'Done' : 'Create',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name & Icon Input Card ──
                _buildNameAndIconCard(isDark, primaryColor),
                const SizedBox(height: 24),

                // ── Included Section ──
                _buildSectionHeader('INCLUDED CHATS'),
                _buildIncludedCard(isDark, primaryColor),
                const SizedBox(height: 24),

                // ── Excluded Section ──
                _buildSectionHeader('EXCLUDED CHATS'),
                _buildExcludedCard(isDark, primaryColor),
                const SizedBox(height: 32),

                // ── Delete Button ──
                if (isEditing)
                  Center(
                    child: TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(CupertinoIcons.trash, color: Color(0xFFEF4444)),
                      label: Text(
                        'Delete Folder',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
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
    );
  }

  Widget _buildNameAndIconCard(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Selected Icon preview
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ChatFolder.availableIcons[_selectedIconKey] ?? CupertinoIcons.folder_fill,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Folder Name TextField
              Expanded(
                child: TextField(
                  controller: _nameController,
                  autofocus: !isEditing,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: LiquidGlassTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Folder Name',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: LiquidGlassTheme.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'CHOOSE ICON',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: LiquidGlassTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          // Icon Picker Row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ChatFolder.availableIcons.entries.map((entry) {
              final isSelected = _selectedIconKey == entry.key;
              return GestureDetector(
                onTap: () => setState(() => _selectedIconKey = entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    entry.value,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    size: 19,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedCard(bool isDark, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          // Filter presets
          SwitchListTile.adaptive(
            title: Text(
              'Personal Chats',
              style: GoogleFonts.inter(fontSize: 14.5, color: LiquidGlassTheme.textPrimary),
            ),
            subtitle: Text(
              '1-on-1 conversations',
              style: GoogleFonts.inter(fontSize: 12, color: LiquidGlassTheme.textMuted),
            ),
            value: _includePersonal,
            activeColor: primaryColor,
            onChanged: (v) => setState(() => _includePersonal = v),
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile.adaptive(
            title: Text(
              'Groups',
              style: GoogleFonts.inter(fontSize: 14.5, color: LiquidGlassTheme.textPrimary),
            ),
            subtitle: Text(
              'Group chats',
              style: GoogleFonts.inter(fontSize: 12, color: LiquidGlassTheme.textMuted),
            ),
            value: _includeGroups,
            activeColor: primaryColor,
            onChanged: (v) => setState(() => _includeGroups = v),
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile.adaptive(
            title: Text(
              'Unread Only',
              style: GoogleFonts.inter(fontSize: 14.5, color: LiquidGlassTheme.textPrimary),
            ),
            subtitle: Text(
              'Only show chats with unread messages',
              style: GoogleFonts.inter(fontSize: 12, color: LiquidGlassTheme.textMuted),
            ),
            value: _includeUnreadOnly,
            activeColor: primaryColor,
            onChanged: (v) => setState(() => _includeUnreadOnly = v),
          ),
          const Divider(height: 1, indent: 16),

          // Add specific chats row
          ListTile(
            leading: Icon(CupertinoIcons.plus_circle_fill, color: primaryColor),
            title: Text(
              'Add Specific Chats',
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            trailing: Text(
              '${_includedUserIds.length + _includedGroupIds.length} added',
              style: GoogleFonts.inter(fontSize: 13, color: LiquidGlassTheme.textSecondary),
            ),
            onTap: () => _openChatPicker(isInclude: true),
          ),
        ],
      ),
    );
  }

  Widget _buildExcludedCard(bool isDark, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: Text(
              'Muted Chats',
              style: GoogleFonts.inter(fontSize: 14.5, color: LiquidGlassTheme.textPrimary),
            ),
            value: _excludeMuted,
            activeColor: primaryColor,
            onChanged: (v) => setState(() => _excludeMuted = v),
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile.adaptive(
            title: Text(
              'Read Chats',
              style: GoogleFonts.inter(fontSize: 14.5, color: LiquidGlassTheme.textPrimary),
            ),
            value: _excludeRead,
            activeColor: primaryColor,
            onChanged: (v) => setState(() => _excludeRead = v),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(CupertinoIcons.minus_circle_fill, color: Color(0xFFEF4444)),
            title: Text(
              'Exclude Specific Chats',
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFEF4444),
              ),
            ),
            trailing: Text(
              '${_excludedUserIds.length + _excludedGroupIds.length} excluded',
              style: GoogleFonts.inter(fontSize: 13, color: LiquidGlassTheme.textSecondary),
            ),
            onTap: () => _openChatPicker(isInclude: false),
          ),
        ],
      ),
    );
  }
}

/// Chat picker sheet with checkboxes for users and groups
class _ChatPickerSheet extends StatefulWidget {
  final List<UserModel> users;
  final List<ChatGroup> groups;
  final List<int> initiallySelectedUserIds;
  final List<int> initiallySelectedGroupIds;
  final void Function(List<int> userIds, List<int> groupIds) onDone;

  const _ChatPickerSheet({
    required this.users,
    required this.groups,
    required this.initiallySelectedUserIds,
    required this.initiallySelectedGroupIds,
    required this.onDone,
  });

  @override
  State<_ChatPickerSheet> createState() => _ChatPickerSheetState();
}

class _ChatPickerSheetState extends State<_ChatPickerSheet> {
  late Set<int> _selectedUsers;
  late Set<int> _selectedGroups;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedUsers = Set<int>.from(widget.initiallySelectedUserIds);
    _selectedGroups = Set<int>.from(widget.initiallySelectedGroupIds);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final primaryColor = ThemeController.instance.primaryColor;

    final filteredUsers = widget.users.where((u) {
      if (_search.isEmpty) return true;
      return u.displayName.toLowerCase().contains(_search) ||
          u.username.toLowerCase().contains(_search);
    }).toList();

    final filteredGroups = widget.groups.where((g) {
      if (_search.isEmpty) return true;
      return g.name.toLowerCase().contains(_search);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: GoogleFonts.inter(color: LiquidGlassTheme.textSecondary)),
                ),
                Text(
                  'Choose Chats',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: LiquidGlassTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onDone(_selectedUsers.toList(), _selectedGroups.toList());
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          // List of Chats
          Expanded(
            child: ListView(
              children: [
                if (filteredGroups.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'GROUPS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: LiquidGlassTheme.textMuted,
                      ),
                    ),
                  ),
                  ...filteredGroups.map((g) {
                    final selected = _selectedGroups.contains(g.id);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: primaryColor,
                      title: Text(g.name, style: GoogleFonts.inter(fontSize: 14.5)),
                      subtitle: Text('${g.memberCount} members', style: GoogleFonts.inter(fontSize: 12)),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedGroups.add(g.id);
                          } else {
                            _selectedGroups.remove(g.id);
                          }
                        });
                      },
                    );
                  }),
                ],
                if (filteredUsers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'CONTACTS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: LiquidGlassTheme.textMuted,
                      ),
                    ),
                  ),
                  ...filteredUsers.map((u) {
                    final selected = _selectedUsers.contains(u.id);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: primaryColor,
                      title: Text(
                        u.displayName.isNotEmpty ? u.displayName : u.username,
                        style: GoogleFonts.inter(fontSize: 14.5),
                      ),
                      subtitle: Text('@${u.username}', style: GoogleFonts.inter(fontSize: 12)),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedUsers.add(u.id);
                          } else {
                            _selectedUsers.remove(u.id);
                          }
                        });
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
