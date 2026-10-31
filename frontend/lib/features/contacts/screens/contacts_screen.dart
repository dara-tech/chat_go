import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/theme/liquid_glass_theme.dart';
import 'package:frontend/core/websocket/chat_socket_service.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/features/chat/screens/chat_search_screen.dart';
import 'package:frontend/features/profile/screens/user_profile_screen.dart';

class ContactsScreen extends StatefulWidget {
  final UserModel currentUser;
  final ValueChanged<UserModel>? onSelectUser;

  const ContactsScreen({
    super.key,
    required this.currentUser,
    this.onSelectUser,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _activeFilter = 'All'; // 'All', 'Online'
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUsers();

    _socketSubscription = ChatSocketService.instance.messageStream.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString();
      if (type == 'user_status') {
        final userId = event['user_id'] is int
            ? event['user_id'] as int
            : int.tryParse(event['user_id']?.toString() ?? '') ?? 0;
        final isOnline = event['is_online'] == true || event['payload']?['is_online'] == true;
        if (userId != 0) {
          setState(() {
            _users = _users.map((u) {
              if (u.id == userId) {
                return u.copyWith(isOnline: isOnline);
              }
              return u;
            }).toList();
          });
        }
      } else if (type == 'online_users_snapshot') {
        final onlineIds = ChatSocketService.instance.onlineUserIds;
        setState(() {
          _users = _users.map((u) {
            return u.copyWith(isOnline: onlineIds.contains(u.id));
          }).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openSearchScreen() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatSearchScreen(
          currentUser: widget.currentUser,
          initialUsers: _users,
        ),
      ),
    );
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiClient.instance.listUsers();
      if (mounted) {
        final onlineIds = ChatSocketService.instance.onlineUserIds;
        setState(() {
          _users = list
              .where((u) => u.username != widget.currentUser.username)
              .map((u) => u.copyWith(isOnline: onlineIds.contains(u.id) || u.isOnline == true))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      if (_activeFilter == 'Online') {
        return u.isOnline == true;
      }
      return true;
    }).toList();

    final onlineCount = _users.where((u) => u.isOnline == true).length;

    return Column(
      children: [
        ValueListenableBuilder<SocketConnectionState>(
          valueListenable: ChatSocketService.instance.connectionStateNotifier,
          builder: (context, connState, _) {
            if (connState == SocketConnectionState.connected) {
              return const SizedBox.shrink();
            }

            final isReconnecting = connState == SocketConnectionState.reconnecting ||
                connState == SocketConnectionState.connecting;
            final text = isReconnecting ? 'Connecting...' : 'Waiting for connection...';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.92),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.06),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CupertinoActivityIndicator(radius: 6, color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Top Header
        _buildHeader(onlineCount),

        // Filter Chips (All, Online)
        _buildFilterChips(onlineCount),

        // Hairline divider
        Divider(
          height: 1,
          thickness: 0.8,
          color: LiquidGlassTheme.dividerHairline,
        ),

        // User List (Continuous seamless surface)
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(LiquidGlassTheme.accentBlue),
                  ),
                )
              : _errorMessage != null
                  ? _buildErrorView()
                  : filtered.isEmpty
                      ? _buildEmptyView()
                      : RefreshIndicator(
                          onRefresh: _fetchUsers,
                          color: LiquidGlassTheme.accentBlue,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.only(top: 4, bottom: 92),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 0.8,
                              indent: 74,
                              endIndent: 0,
                              color: LiquidGlassTheme.dividerHairline,
                            ),
                            itemBuilder: (context, index) {
                              final user = filtered[index];
                              return _buildUserTile(user);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildHeader(int onlineCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                'People',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: LiquidGlassTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_users.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlassTheme.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          // Search action icon
          GestureDetector(
            onTap: _openSearchScreen,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LiquidGlassTheme.inputFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.search,
                size: 17,
                color: LiquidGlassTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int onlineCount) {
    final filters = [
      {'label': 'All', 'count': _users.length},
      {'label': 'Online', 'count': onlineCount},
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final label = filter['label'] as String;
          final count = filter['count'] as int;
          final isSelected = _activeFilter == label;

          return GestureDetector(
            onTap: () => setState(() => _activeFilter = label),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? LiquidGlassTheme.accentBlue
                    : LiquidGlassTheme.inputFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? LiquidGlassTheme.accentBlue
                      : LiquidGlassTheme.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : LiquidGlassTheme.textSecondary,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : LiquidGlassTheme.borderSubtle,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : LiquidGlassTheme.textMuted,
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
  }

  Widget _buildUserTile(UserModel user) {
    void openProfile() {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => UserProfileScreen(
            userId: user.id,
            initialUser: user,
            currentUser: widget.currentUser,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.onSelectUser != null) {
            widget.onSelectUser!(user);
          } else {
            openProfile();
          }
        },
        onLongPress: openProfile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with online status badge & network image support (tappable to view profile)
              GestureDetector(
                onTap: openProfile,
                child: Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: LiquidGlassTheme.isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [LiquidGlassTheme.bgClayDim, LiquidGlassTheme.bgClayDimDarker],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: (user.avatarUrl.isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                ApiClient.resolveAvatarUrl(user.avatarUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Text(
                                    user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: LiquidGlassTheme.accentBlue,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: LiquidGlassTheme.accentBlue,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: user.isOnline ? LiquidGlassTheme.accentEmerald : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                          border: Border.all(color: LiquidGlassTheme.bgCard, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.displayName.isNotEmpty ? user.displayName : user.username,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: LiquidGlassTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: LiquidGlassTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Online / Offline Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isOnline
                      ? LiquidGlassTheme.accentEmerald.withOpacity(0.12)
                      : LiquidGlassTheme.inputFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: user.isOnline
                        ? LiquidGlassTheme.accentEmerald.withOpacity(0.25)
                        : LiquidGlassTheme.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  user.isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: user.isOnline ? LiquidGlassTheme.accentEmerald : LiquidGlassTheme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Info Icon Action
              GestureDetector(
                onTap: openProfile,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    CupertinoIcons.info_circle,
                    size: 20,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_3, size: 48, color: LiquidGlassTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'No members found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.red, size: 36),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed loading members',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: LiquidGlassTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchUsers,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
