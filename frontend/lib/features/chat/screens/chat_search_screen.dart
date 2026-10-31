import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/liquid_glass_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/widgets/app_search_bar.dart';
import 'chat_screen.dart';

class ChatSearchScreen extends StatefulWidget {
  final UserModel currentUser;
  final List<UserModel> initialUsers;

  const ChatSearchScreen({
    super.key,
    required this.currentUser,
    required this.initialUsers,
  });

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _activeTab = 'All'; // 'All', 'Chats', 'Users', 'Online'
  late List<UserModel> _users;

  final List<String> _tabs = const ['All', 'Chats', 'Users', 'Online'];

  @override
  void initState() {
    super.initState();
    _users = List.from(widget.initialUsers);
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openChatWithUser(UserModel user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUser: widget.currentUser,
          title: user.displayName.isNotEmpty ? user.displayName : user.username,
          chatUser: user,
        ),
      ),
    );
  }


  List<UserModel> _getFilteredUsers() {
    return _users.where((u) {
      if (_activeTab == 'Online' && !u.isOnline) {
        return false;
      }
      if (_searchQuery.isEmpty) {
        return true;
      }
      final nameMatch = u.displayName.toLowerCase().contains(_searchQuery);
      final userMatch = u.username.toLowerCase().contains(_searchQuery);
      return nameMatch || userMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();

    return Scaffold(
      backgroundColor: ThemeController.instance.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Telegram-style Search Bar & Cancel button
            _buildSearchHeader(),

            // 2. Telegram Category Filter Chips
            _buildFilterTabs(),

            // Hairline separator
            Divider(
              height: 1,
              thickness: 0.8,
              color: LiquidGlassTheme.borderSubtle,
            ),

            // 3. Search Results or Recent List
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildRecentAndSuggestedView()
                  : _buildSearchResultsView(filteredUsers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return AppSearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      hintText: 'Search (⌘K)',
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      onClose: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isSelected = _activeTab == tab;

          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? LiquidGlassTheme.accentBlue.withOpacity(0.16)
                    : LiquidGlassTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? LiquidGlassTheme.accentBlue.withOpacity(0.35)
                      : LiquidGlassTheme.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Text(
                tab,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? LiquidGlassTheme.accentBlue
                      : LiquidGlassTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentAndSuggestedView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // 1. Recent Horizontal Contacts (Telegram signature look)
        if (_users.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'RECENT CHATS',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: LiquidGlassTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _users.take(8).length,
              separatorBuilder: (_, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final u = _users[index];
                final initial = u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U';
                final shortName = u.displayName.isNotEmpty
                    ? u.displayName.split(' ').first
                    : u.username;

                return GestureDetector(
                  onTap: () => _openChatWithUser(u),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 58,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: LiquidGlassTheme.isDark
                                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                      : [LiquidGlassTheme.bgClayDim, LiquidGlassTheme.bgClayDimDarker],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: LiquidGlassTheme.accentBlue,
                                  ),
                                ),
                              ),
                            ),
                            if (u.isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: LiquidGlassTheme.accentEmerald,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ThemeController.instance.scaffoldBg,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: LiquidGlassTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 0.8,
            color: LiquidGlassTheme.borderSubtle,
          ),
          const SizedBox(height: 12),
        ],

        // 2. Suggested Contacts Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'SUGGESTED CONTACTS',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: LiquidGlassTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),

        // User list tiles
        ..._users.map((u) => _buildUserSearchTile(u)),
      ],
    );
  }

  Widget _buildSearchResultsView(List<UserModel> filteredUsers) {
    if (filteredUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.inputFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
                ),
                child: Icon(
                  CupertinoIcons.search,
                  size: 26,
                  color: LiquidGlassTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Results',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: LiquidGlassTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No contacts found for "$_searchQuery"',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: LiquidGlassTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CHATS AND CONTACTS',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: LiquidGlassTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${filteredUsers.length} found',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: LiquidGlassTheme.accentBlue,
                ),
              ),
            ],
          ),
        ),
        ...filteredUsers.map((u) => _buildUserSearchTile(u)),
      ],
    );
  }

  Widget _buildUserSearchTile(UserModel user) {
    final initial = user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openChatWithUser(user),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // User Avatar
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: LiquidGlassTheme.isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [LiquidGlassTheme.bgClayDim, LiquidGlassTheme.bgClayDimDarker],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: LiquidGlassTheme.accentBlue,
                        ),
                      ),
                    ),
                  ),
                  if (user.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: LiquidGlassTheme.accentEmerald,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ThemeController.instance.scaffoldBg,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Names
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty ? user.displayName : user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: LiquidGlassTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: LiquidGlassTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status chip
              if (user.isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.accentEmerald.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'online',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: LiquidGlassTheme.accentEmerald,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
