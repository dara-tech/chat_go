import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';

class CreateGroupSheet {
  static Future<ChatGroup?> show({
    required BuildContext context,
    required UserModel currentUser,
  }) async {
    HapticFeedback.mediumImpact();

    return Navigator.of(context).push<ChatGroup>(
      CupertinoPageRoute(
        builder: (_) => CreateGroupScreen(currentUser: currentUser),
      ),
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  final UserModel currentUser;

  const CreateGroupScreen({super.key, required this.currentUser});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<UserModel> _allUsers = [];
  final Set<int> _selectedUserIds = {};
  bool _isLoadingUsers = true;
  bool _isCreating = false;
  String _searchQuery = '';
  String? _errorMessage;
  int _step = 0; // 0: Select members, 1: Enter group details

  static const List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ApiClient.instance.listUsers(limit: 100);
      if (mounted) {
        final filtered = users.where((u) => u.id != widget.currentUser.id).toList();
        filtered.sort((a, b) {
          final nameA = (a.displayName.isNotEmpty ? a.displayName : a.username).toLowerCase();
          final nameB = (b.displayName.isNotEmpty ? b.displayName : b.username).toLowerCase();
          return nameA.compareTo(nameB);
        });

        setState(() {
          _allUsers = filtered;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
          _errorMessage = 'Failed to load contacts: $e';
        });
      }
    }
  }

  String _getSectionKey(String name) {
    if (name.isEmpty) return '#';
    final first = name.trim().substring(0, 1).toUpperCase();
    if (RegExp(r'^[A-Z]$').hasMatch(first)) {
      return first;
    }
    return '#';
  }

  Map<String, List<UserModel>> _groupUsersByAlphabet(List<UserModel> users) {
    final Map<String, List<UserModel>> map = {};
    for (final user in users) {
      final name = user.displayName.isNotEmpty ? user.displayName : user.username;
      final key = _getSectionKey(name);
      map.putIfAbsent(key, () => []).add(user);
    }
    return map;
  }

  void _scrollToSection(String letter) {
    HapticFeedback.selectionClick();
    final key = _sectionKeys[letter];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
    }
  }

  Future<void> _handleCreateGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a group name');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final group = await ApiClient.instance.createGroup(
        name: name,
        description: _descController.text.trim(),
        memberIds: _selectedUserIds.toList(),
      );
      if (mounted) {
        Navigator.of(context).pop(group);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        top: true,
        bottom: true,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _step == 0 ? _buildMemberSelectionStep() : _buildGroupDetailsStep(),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // STEP 1: MEMBER SELECTION (Matching Screenshot)
  // ----------------------------------------------------
  Widget _buildMemberSelectionStep() {
    final filteredUsers = _allUsers.where((u) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.displayName.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q);
    }).toList();

    final grouped = _groupUsersByAlphabet(filteredUsers);
    final sortedSections = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    return Stack(
      children: [
        Column(
          children: [
            // Top Navigation Bar
            _buildTopNavBar(
              title: 'New Group',
              subtitle: '${_selectedUserIds.length}/200000',
              rightActionText: 'Next',
              onBack: () => Navigator.of(context).pop(),
              onRightAction: _selectedUserIds.isEmpty
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() => _step = 1);
                    },
            ),

            // Search input bar ("Who would you like to add?")
            _buildSearchInput(),

            // Selected members horizontal avatar chips
            if (_selectedUserIds.isNotEmpty) _buildSelectedMembersHorizontalBar(),

            // Contacts List
            Expanded(
              child: _isLoadingUsers
                  ? const Center(child: CupertinoActivityIndicator(radius: 12))
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            'No contacts found',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: LiquidGlassTheme.textMuted,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.only(bottom: 32),
                          itemCount: sortedSections.length,
                          itemBuilder: (context, sectionIdx) {
                            final sectionKey = sortedSections[sectionIdx];
                            final usersInSection = grouped[sectionKey]!;

                            _sectionKeys.putIfAbsent(sectionKey, () => GlobalKey());

                            return Column(
                              key: _sectionKeys[sectionKey],
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section Letter Header ("A", "B", etc.)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                                  child: Text(
                                    sectionKey,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: LiquidGlassTheme.textMuted,
                                    ),
                                  ),
                                ),

                                // Contacts in this section
                                ...usersInSection.map((user) => _buildContactRow(user)),
                              ],
                            );
                          },
                        ),
            ),
          ],
        ),

        // Right Alphabet fast-scroller bar
        if (_searchQuery.isEmpty && !_isLoadingUsers && sortedSections.isNotEmpty)
          Positioned(
            right: 2,
            top: 100,
            bottom: 40,
            child: _buildAlphabetBar(sortedSections),
          ),
      ],
    );
  }

  // ----------------------------------------------------
  // STEP 2: GROUP DETAILS (Name, Photo, Description)
  // ----------------------------------------------------
  Widget _buildGroupDetailsStep() {
    return Column(
      children: [
        _buildTopNavBar(
          title: 'New Group Info',
          subtitle: '${_selectedUserIds.length} members',
          rightActionText: 'Create',
          isLoadingRightAction: _isCreating,
          onBack: () => setState(() => _step = 0),
          onRightAction: _handleCreateGroup,
        ),
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(fontSize: 13.5, color: Colors.redAccent),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Group Avatar with camera icon
                Center(
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          LiquidGlassTheme.accentBlue,
                          LiquidGlassTheme.accentIndigo,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: LiquidGlassTheme.accentBlue.withOpacity(0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Group Name text field
                Container(
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.isDark
                        ? const Color(0xFF141824)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: LiquidGlassTheme.borderSubtle.withOpacity(0.6),
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: LiquidGlassTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter group name',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15,
                        color: LiquidGlassTheme.textMuted.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Group Description text field
                Container(
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.isDark
                        ? const Color(0xFF141824)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: LiquidGlassTheme.borderSubtle.withOpacity(0.6),
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _descController,
                    maxLines: 3,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: LiquidGlassTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Group description (optional)',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: LiquidGlassTheme.textMuted.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Members list preview
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'MEMBERS (${_selectedUserIds.length})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: LiquidGlassTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ..._selectedUserIds.map((uId) {
                  final user = _allUsers.firstWhere(
                    (u) => u.id == uId,
                    orElse: () => UserModel(
                      id: uId,
                      uuid: '',
                      username: 'User $uId',
                      email: '',
                      displayName: 'User $uId',
                      avatarUrl: '',
                      isOnline: false,
                      createdAt: DateTime.now(),
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: LiquidGlassTheme.accentBlue.withOpacity(0.18),
                          backgroundImage: user.avatarUrl.isNotEmpty
                              ? NetworkImage(ApiClient.resolveAvatarUrl(user.avatarUrl))
                              : null,
                          child: user.avatarUrl.isEmpty
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: LiquidGlassTheme.accentBlue,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            user.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: LiquidGlassTheme.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          user.isOnline ? 'online' : 'offline',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: user.isOnline
                                ? LiquidGlassTheme.accentBlue
                                : LiquidGlassTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // TOP NAVIGATION BAR (Matching Screenshot)
  // ----------------------------------------------------
  Widget _buildTopNavBar({
    required String title,
    required String subtitle,
    required String rightActionText,
    required VoidCallback onBack,
    required VoidCallback? onRightAction,
    bool isLoadingRightAction = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonCircleBg = isDark ? const Color(0xFF1B202A) : const Color(0xFFE2E8F0);
    final isActionEnabled = onRightAction != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Dark Circular Back Pill ("<")
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: buttonCircleBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                size: 19,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
          ),

          // Center: Title & Subtitle ("New Group" & "0/200000")
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: LiquidGlassTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: LiquidGlassTheme.textMuted,
                ),
              ),
            ],
          ),

          // Right: Pill Action Button ("Next" or "Create")
          isLoadingRightAction
              ? const SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(child: CupertinoActivityIndicator(radius: 9)),
                )
              : GestureDetector(
                  onTap: onRightAction,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActionEnabled
                          ? (isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0))
                          : (isDark ? const Color(0xFF141720) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActionEnabled
                            ? LiquidGlassTheme.accentBlue.withOpacity(0.5)
                            : Colors.transparent,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      rightActionText,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isActionEnabled
                            ? (isDark ? Colors.white : LiquidGlassTheme.textPrimary)
                            : LiquidGlassTheme.textMuted.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // CAPSULE SEARCH INPUT ("Who would you like to add?")
  // ----------------------------------------------------
  Widget _buildSearchInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillBg = isDark ? const Color(0xFF131720) : const Color(0xFFF1F5F9);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: fillBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LiquidGlassTheme.borderSubtle.withOpacity(0.3),
          width: 0.6,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: LiquidGlassTheme.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: InputBorder.none,
          hintText: 'Who would you like to add?',
          hintStyle: GoogleFonts.inter(
            fontSize: 14.5,
            color: LiquidGlassTheme.textMuted.withOpacity(0.65),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(
                    CupertinoIcons.clear_circled_solid,
                    size: 16,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
      ),
    );
  }

  // ----------------------------------------------------
  // SELECTED MEMBERS HORIZONTAL ROW (Under search)
  // ----------------------------------------------------
  Widget _buildSelectedMembersHorizontalBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _selectedUserIds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final uId = _selectedUserIds.elementAt(idx);
              final user = _allUsers.firstWhere(
                (u) => u.id == uId,
                orElse: () => UserModel(
                  id: uId,
                  uuid: '',
                  username: 'User $uId',
                  email: '',
                  displayName: 'User $uId',
                  avatarUrl: '',
                  isOnline: false,
                  createdAt: DateTime.now(),
                ),
              );
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedUserIds.remove(uId));
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: LiquidGlassTheme.accentBlue.withOpacity(0.18),
                          backgroundImage: user.avatarUrl.isNotEmpty
                              ? NetworkImage(ApiClient.resolveAvatarUrl(user.avatarUrl))
                              : null,
                          child: user.avatarUrl.isEmpty
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: LiquidGlassTheme.accentBlue,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF64748B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 52,
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: LiquidGlassTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.6,
          color: LiquidGlassTheme.dividerHairline.withOpacity(0.4),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // CONTACT ROW (Matching Screenshot)
  // ----------------------------------------------------
  Widget _buildContactRow(UserModel user) {
    final isSelected = _selectedUserIds.contains(user.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatarColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];
    final color = avatarColors[user.id % avatarColors.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (isSelected) {
              _selectedUserIds.remove(user.id);
            } else {
              _selectedUserIds.add(user.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  // Far left: Circular selection ring
                  Container(
                    margin: const EdgeInsets.only(left: 16, right: 14),
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? LiquidGlassTheme.accentBlue : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? LiquidGlassTheme.accentBlue
                            : (isDark ? const Color(0xFF3F4756) : const Color(0xFFCBD5E1)),
                        width: 1.8,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(CupertinoIcons.checkmark, size: 13, color: Colors.white)
                        : null,
                  ),

                  // Avatar
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: color.withOpacity(0.18),
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(ApiClient.resolveAvatarUrl(user.avatarUrl))
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName.substring(0, 1).toUpperCase()
                                : 'U',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),

                  // Title & Subtitle ("online" or "last seen recently")
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName.isNotEmpty ? user.displayName : user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: LiquidGlassTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.isOnline ? 'online' : 'last seen recently',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: user.isOnline
                                ? LiquidGlassTheme.accentBlue
                                : LiquidGlassTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right spacing so text doesn't overlap the alphabet bar
                  const SizedBox(width: 32),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 88,
                endIndent: 28,
                color: LiquidGlassTheme.dividerHairline.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // ALPHABET INDEX BAR ON THE RIGHT (A B C D ... #)
  // ----------------------------------------------------
  Widget _buildAlphabetBar(List<String> activeSections) {
    return Center(
      child: Container(
        width: 24,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: _alphabet.map((letter) {
            final hasSection = activeSections.contains(letter);

            return GestureDetector(
              onTap: hasSection ? () => _scrollToSection(letter) : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.0),
                child: Text(
                  letter,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: hasSection
                        ? LiquidGlassTheme.accentBlue
                        : LiquidGlassTheme.textMuted.withOpacity(0.35),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
