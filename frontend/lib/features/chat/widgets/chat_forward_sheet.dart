import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/local_chat_storage.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/chat_message.dart';
import '../../../models/user_model.dart';

/// Themed Telegram-style Forward Sheet matching app theme and design guidelines.
class ChatForwardSheet {
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> msg,
    required UserModel currentUser,
    required Function(UserModel recipient) onForwardToUser,
  }) async {
    HapticFeedback.mediumImpact();

    // Pre-fetch cached conversations and users
    List<ChatConversation> conversations = [];
    List<UserModel> contacts = [];
    try {
      conversations = await LocalChatStorage.instance.getCachedConversations();
    } catch (_) {}

    try {
      final fetched = await ApiClient.instance.listUsers(limit: 60);
      contacts = fetched.where((u) => u.id != currentUser.id).toList();
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.60),
      builder: (sheetContext) => _ThemedForwardSheetWidget(
        msg: msg,
        currentUser: currentUser,
        initialConversations: conversations,
        initialContacts: contacts,
        onForwardToUser: onForwardToUser,
      ),
    );
  }
}

class _ThemedForwardSheetWidget extends StatefulWidget {
  final Map<String, dynamic> msg;
  final UserModel currentUser;
  final List<ChatConversation> initialConversations;
  final List<UserModel> initialContacts;
  final Function(UserModel recipient) onForwardToUser;

  const _ThemedForwardSheetWidget({
    required this.msg,
    required this.currentUser,
    required this.initialConversations,
    required this.initialContacts,
    required this.onForwardToUser,
  });

  @override
  State<_ThemedForwardSheetWidget> createState() => _ThemedForwardSheetWidgetState();
}

class _ThemedForwardSheetWidgetState extends State<_ThemedForwardSheetWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _activeBottomTab = 0; // 0: Chats, 1: Contacts
  bool _isSelectionMode = false;
  final Set<int> _selectedRecipientIds = {};
  final Map<int, UserModel> _selectedUsersMap = {};

  late List<ChatConversation> _conversations;
  late List<UserModel> _contacts;

  @override
  void initState() {
    super.initState();
    _conversations = List.from(widget.initialConversations);
    _contacts = List.from(widget.initialContacts);

    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });

    _refreshData();
  }

  Future<void> _refreshData() async {
    try {
      final freshUsers = await ApiClient.instance.listUsers(limit: 60);
      if (mounted) {
        setState(() {
          _contacts = freshUsers.where((u) => u.id != widget.currentUser.id).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  UserModel get _savedMessagesUser => UserModel(
        id: widget.currentUser.id,
        uuid: widget.currentUser.uuid,
        username: widget.currentUser.username,
        email: widget.currentUser.email,
        displayName: 'Saved Messages',
        avatarUrl: widget.currentUser.avatarUrl,
        isOnline: true,
        createdAt: widget.currentUser.createdAt,
      );

  void _handleSelectUser(UserModel user) {
    HapticFeedback.selectionClick();
    if (_isSelectionMode) {
      setState(() {
        if (_selectedRecipientIds.contains(user.id)) {
          _selectedRecipientIds.remove(user.id);
          _selectedUsersMap.remove(user.id);
        } else {
          _selectedRecipientIds.add(user.id);
          _selectedUsersMap[user.id] = user;
        }
      });
    } else {
      _forwardAndClose([user]);
    }
  }

  void _forwardAndClose(List<UserModel> recipients) {
    if (recipients.isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();

    for (final recipient in recipients) {
      widget.onForwardToUser(recipient);
    }

    final recipientNames = recipients.map((r) => r.displayName.isNotEmpty ? r.displayName : r.username).join(', ');
    final theme = ThemeController.instance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          recipients.length == 1
              ? 'Forwarded to $recipientNames'
              : 'Forwarded to ${recipients.length} recipients',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: theme.bgPreset.cardBg,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sendSelected() {
    final recipients = _selectedUsersMap.values.toList();
    _forwardAndClose(recipients);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final bgPreset = theme.bgPreset;
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: bgPreset.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: bgPreset.border.withOpacity(0.5),
            width: 0.8,
          ),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Drag Indicator Pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 2),
                  decoration: BoxDecoration(
                    color: bgPreset.textMuted.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 1. Top Header Bar (Close, Title, Select/Send Button)
              _buildTopHeader(theme),

              // 2. Themed Search Bar
              _buildSearchBar(theme),

              const SizedBox(height: 4),

              // 3. Main Chat / Contact List
              Expanded(
                child: _buildListContent(theme),
              ),
            ],
          ),

          // 4. Floating Bottom Segment Switcher (Chats | Contacts)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 14,
            left: 0,
            right: 0,
            child: Center(
              child: _buildBottomTabSwitcher(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(ThemeController theme) {
    final bgPreset = theme.bgPreset;
    final accent = theme.current;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button (themed circle with cross)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgPreset.inputFill,
                shape: BoxShape.circle,
                border: Border.all(color: bgPreset.border.withOpacity(0.3), width: 0.6),
              ),
              child: Icon(
                CupertinoIcons.xmark,
                size: 15,
                color: bgPreset.textPrimary,
              ),
            ),
          ),

          // Center Title
          Text(
            'Forward',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: bgPreset.textPrimary,
            ),
          ),

          // Right Select / Send button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_isSelectionMode && _selectedRecipientIds.isNotEmpty) {
                _sendSelected();
              } else {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) {
                    _selectedRecipientIds.clear();
                    _selectedUsersMap.clear();
                  }
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
              decoration: BoxDecoration(
                color: _isSelectionMode && _selectedRecipientIds.isNotEmpty
                    ? accent.primary
                    : bgPreset.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSelectionMode && _selectedRecipientIds.isNotEmpty
                      ? accent.primary
                      : bgPreset.border.withOpacity(0.3),
                  width: 0.6,
                ),
              ),
              child: Text(
                _isSelectionMode
                    ? (_selectedRecipientIds.isNotEmpty ? 'Send (${_selectedRecipientIds.length})' : 'Cancel')
                    : 'Select',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _isSelectionMode && _selectedRecipientIds.isNotEmpty
                      ? Colors.white
                      : bgPreset.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeController theme) {
    final bgPreset = theme.bgPreset;
    final accent = theme.current;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: bgPreset.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: bgPreset.border.withOpacity(0.4), width: 0.6),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.inter(fontSize: 14.5, color: bgPreset.textPrimary),
          cursorColor: accent.primary,
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: GoogleFonts.inter(fontSize: 14.5, color: bgPreset.textMuted),
            prefixIcon: Icon(
              CupertinoIcons.search,
              size: 17,
              color: bgPreset.textMuted,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: Icon(CupertinoIcons.clear_thick_circled, size: 16, color: bgPreset.textMuted),
                  )
                : null,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(ThemeController theme) {
    if (_activeBottomTab == 0) {
      return _buildChatsList(theme);
    } else {
      return _buildContactsList(theme);
    }
  }

  Widget _buildChatsList(ThemeController theme) {
    List<ChatConversation> filteredConversations = _conversations.where((c) {
      if (_searchQuery.isNotEmpty) {
        final name = c.user.displayName.isNotEmpty ? c.user.displayName : c.user.username;
        return name.toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();

    final showSavedMessages = _searchQuery.isEmpty || 'saved messages'.contains(_searchQuery);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: (showSavedMessages ? 1 : 0) + filteredConversations.length,
      itemBuilder: (context, index) {
        if (showSavedMessages && index == 0) {
          final isSelected = _selectedRecipientIds.contains(widget.currentUser.id);
          return _buildChatRow(
            theme: theme,
            title: 'Saved Messages',
            avatar: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.current.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.bookmark_fill,
                color: Colors.white,
                size: 20,
              ),
            ),
            isVerified: false,
            isSelected: isSelected,
            onTap: () => _handleSelectUser(_savedMessagesUser),
          );
        }

        final convIndex = showSavedMessages ? index - 1 : index;
        final conv = filteredConversations[convIndex];
        final user = conv.user;
        final title = user.displayName.isNotEmpty ? user.displayName : user.username;
        final isSelected = _selectedRecipientIds.contains(user.id);

        return _buildChatRow(
          theme: theme,
          title: title,
          avatar: _buildUserAvatar(user, theme),
          isVerified: title.toLowerCase().contains('chat') || title.toLowerCase().contains('official'),
          isSelected: isSelected,
          onTap: () => _handleSelectUser(user),
        );
      },
    );
  }

  Widget _buildContactsList(ThemeController theme) {
    List<UserModel> filteredContacts = _contacts.where((u) {
      if (_searchQuery.isNotEmpty) {
        final name = u.displayName.isNotEmpty ? u.displayName : u.username;
        return name.toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();

    if (filteredContacts.isEmpty) {
      return Center(
        child: Text(
          'No contacts found',
          style: GoogleFonts.inter(fontSize: 14, color: theme.bgPreset.textMuted),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: filteredContacts.length,
      itemBuilder: (context, index) {
        final user = filteredContacts[index];
        final title = user.displayName.isNotEmpty ? user.displayName : user.username;
        final isSelected = _selectedRecipientIds.contains(user.id);

        return _buildChatRow(
          theme: theme,
          title: title,
          avatar: _buildUserAvatar(user, theme),
          isVerified: false,
          isSelected: isSelected,
          onTap: () => _handleSelectUser(user),
        );
      },
    );
  }

  Widget _buildChatRow({
    required ThemeController theme,
    required String title,
    required Widget avatar,
    required bool isVerified,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bgPreset = theme.bgPreset;
    final accent = theme.current;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: accent.primary.withOpacity(0.08),
        highlightColor: accent.primary.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Avatar
              avatar,
              const SizedBox(width: 14),

              // Title and verified badge
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: bgPreset.textPrimary,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 15,
                        color: accent.primary,
                      ),
                    ],
                  ],
                ),
              ),

              // Selection checkmark if in selection mode
              if (_isSelectionMode)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accent.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? accent.primary : bgPreset.textMuted.withOpacity(0.50),
                      width: 1.8,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(UserModel user, ThemeController theme) {
    final avatarUrl = ApiClient.resolveAvatarUrl(user.avatarUrl);
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.bgPreset.inputFill,
        shape: BoxShape.circle,
        border: Border.all(color: theme.bgPreset.border.withOpacity(0.4), width: 0.6),
      ),
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => _buildAvatarFallback(initial, theme),
              )
            : _buildAvatarFallback(initial, theme),
      ),
    );
  }

  Widget _buildAvatarFallback(String initial, ThemeController theme) {
    return Container(
      color: theme.current.primary.withOpacity(0.18),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.current.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTabSwitcher(ThemeController theme) {
    final bgPreset = theme.bgPreset;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bgPreset.surfaceBg.withOpacity(0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: bgPreset.border.withOpacity(0.5), width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegmentPill('Chats', 0, theme),
              _buildSegmentPill('Contacts', 1, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentPill(String title, int index, ThemeController theme) {
    final isActive = _activeBottomTab == index;
    final accent = theme.current;
    final bgPreset = theme.bgPreset;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeBottomTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? accent.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? Colors.white : bgPreset.textSecondary,
          ),
        ),
      ),
    );
  }
}
