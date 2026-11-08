import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/chat_folder_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/chat_folder_model.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';

class EditChatFolderScreen extends StatefulWidget {
  final ChatFolder? existingFolder;
  final List<UserModel> availableUsers;
  final List<ChatGroup> availableGroups;
  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  const EditChatFolderScreen({
    super.key,
    this.existingFolder,
    this.availableUsers = const [],
    this.availableGroups = const [],
    this.onBack,
    this.onSaved,
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

    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _delete() {
    if (widget.existingFolder != null) {
      ChatFolderController.instance.deleteFolder(widget.existingFolder!.id);
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
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
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        final primaryColor = ThemeController.instance.primaryColor;
        final scaffoldBg = ThemeController.instance.scaffoldBg;
        final borderColor = ThemeController.instance.border;
        final textPrimary = ThemeController.instance.textPrimary;

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: textPrimary),
              onPressed: _handleBack,
            ),
            title: Text(
              isEditing ? 'Edit Folder' : 'New Folder',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textPrimary,
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
              constraints: const BoxConstraints(maxWidth: 580),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Name & Icon Input Card ──
                    _buildNameAndIconCard(isDark, primaryColor, borderColor),
                    const SizedBox(height: 24),

                    // ── Included Section ──
                    _buildSectionHeader('INCLUDED CHATS'),
                    _buildIncludedCard(isDark, primaryColor, borderColor),
                    const SizedBox(height: 24),

                    // ── Excluded Section ──
                    _buildSectionHeader('EXCLUDED CHATS'),
                    _buildExcludedCard(isDark, primaryColor, borderColor),
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
      },
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
          color: ThemeController.instance.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNameAndIconCard(bool isDark, Color primaryColor, Color borderColor) {
    final cardBg = ThemeController.instance.cardBg;
    final dividerColor = ThemeController.instance.divider;
    final textPrimary = ThemeController.instance.textPrimary;
    final textMuted = ThemeController.instance.textMuted;
    final inputFill = ThemeController.instance.inputFill;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Folder Name',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: textMuted,
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
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 12),
          Text(
            'CHOOSE ICON',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          // Icon Picker Wrap
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
                    color: isSelected ? primaryColor : inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    entry.value,
                    color: isSelected
                        ? Colors.white
                        : ThemeController.instance.textSecondary,
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

  Widget _buildToggleRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color primaryColor,
    required Color borderColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: ThemeController.instance.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: ThemeController.instance.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoSwitch(
                value: value,
                activeColor: primaryColor,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, color: ThemeController.instance.divider),
      ],
    );
  }

  Widget _buildIncludedCard(bool isDark, Color primaryColor, Color borderColor) {
    final cardBg = ThemeController.instance.cardBg;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            title: 'Personal Chats',
            subtitle: '1-on-1 conversations',
            value: _includePersonal,
            onChanged: (v) => setState(() => _includePersonal = v),
            primaryColor: primaryColor,
            borderColor: borderColor,
          ),
          _buildToggleRow(
            title: 'Groups',
            subtitle: 'Group chats',
            value: _includeGroups,
            onChanged: (v) => setState(() => _includeGroups = v),
            primaryColor: primaryColor,
            borderColor: borderColor,
          ),
          _buildToggleRow(
            title: 'Unread Only',
            subtitle: 'Only show chats with unread messages',
            value: _includeUnreadOnly,
            onChanged: (v) => setState(() => _includeUnreadOnly = v),
            primaryColor: primaryColor,
            borderColor: borderColor,
          ),

          // Add specific chats row
          InkWell(
            onTap: () => _openChatPicker(isInclude: true),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(CupertinoIcons.plus_circle_fill, size: 20, color: primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add Specific Chats',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  if (_includedUserIds.isNotEmpty || _includedGroupIds.isNotEmpty)
                    Text(
                      '${_includedUserIds.length + _includedGroupIds.length} added',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: ThemeController.instance.textSecondary,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: ThemeController.instance.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcludedCard(bool isDark, Color primaryColor, Color borderColor) {
    final cardBg = ThemeController.instance.cardBg;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            title: 'Muted Chats',
            value: _excludeMuted,
            onChanged: (v) => setState(() => _excludeMuted = v),
            primaryColor: primaryColor,
            borderColor: borderColor,
          ),
          _buildToggleRow(
            title: 'Read Chats',
            value: _excludeRead,
            onChanged: (v) => setState(() => _excludeRead = v),
            primaryColor: primaryColor,
            borderColor: borderColor,
          ),

          // Exclude specific chats row
          InkWell(
            onTap: () => _openChatPicker(isInclude: false),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.minus_circle_fill, size: 20, color: Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Exclude Specific Chats',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  if (_excludedUserIds.isNotEmpty || _excludedGroupIds.isNotEmpty)
                    Text(
                      '${_excludedUserIds.length + _excludedGroupIds.length} excluded',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: ThemeController.instance.textSecondary,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: ThemeController.instance.textMuted,
                  ),
                ],
              ),
            ),
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
    final primaryColor = ThemeController.instance.primaryColor;
    final cardBg = ThemeController.instance.cardBg;
    final textPrimary = ThemeController.instance.textPrimary;
    final textSecondary = ThemeController.instance.textSecondary;
    final textMuted = ThemeController.instance.textMuted;
    final inputFill = ThemeController.instance.inputFill;

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
        color: cardBg,
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
                  child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary)),
                ),
                Text(
                  'Choose Chats',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
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
                color: inputFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                style: GoogleFonts.inter(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  prefixIcon: Icon(CupertinoIcons.search, size: 16, color: textMuted),
                  hintText: 'Search chats...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),

          // Chat items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                if (filteredUsers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'USERS',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
                    ),
                  ),
                  ...filteredUsers.map((u) {
                    final isChecked = _selectedUsers.contains(u.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: primaryColor.withOpacity(0.15),
                        child: Text(
                          u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(u.displayName, style: GoogleFonts.inter(fontSize: 14.5, color: textPrimary)),
                      subtitle: Text('@${u.username}', style: GoogleFonts.inter(fontSize: 12, color: textMuted)),
                      trailing: Icon(
                        isChecked ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                        color: isChecked ? primaryColor : textMuted,
                      ),
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _selectedUsers.remove(u.id);
                          } else {
                            _selectedUsers.add(u.id);
                          }
                        });
                      },
                    );
                  }),
                ],

                if (filteredGroups.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      'GROUPS',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
                    ),
                  ),
                  ...filteredGroups.map((g) {
                    final isChecked = _selectedGroups.contains(g.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: primaryColor.withOpacity(0.15),
                        child: Icon(CupertinoIcons.person_2_fill, color: primaryColor, size: 18),
                      ),
                      title: Text(g.name, style: GoogleFonts.inter(fontSize: 14.5, color: textPrimary)),
                      subtitle: Text('${g.members.length} members', style: GoogleFonts.inter(fontSize: 12, color: textMuted)),
                      trailing: Icon(
                        isChecked ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                        color: isChecked ? primaryColor : textMuted,
                      ),
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _selectedGroups.remove(g.id);
                          } else {
                            _selectedGroups.add(g.id);
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
