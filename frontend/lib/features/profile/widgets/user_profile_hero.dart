import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../models/user_model.dart';

class UserProfileHero extends StatelessWidget {
  final UserModel user;
  final String lastSeenText;
  final VoidCallback onOpenAvatar;

  const UserProfileHero({
    super.key,
    required this.user,
    required this.lastSeenText,
    required this.onOpenAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final avatarResolved = ApiClient.resolveAvatarUrl(user.avatarUrl);
    final hasAvatar = user.avatarUrl.isNotEmpty;

    return Center(
      child: Column(
        children: [
          // Avatar with hero border and online indicator
          GestureDetector(
            onTap: onOpenAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        LiquidGlassTheme.accentBlue,
                        LiquidGlassTheme.accentIndigo,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: LiquidGlassTheme.accentBlue.withOpacity(0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LiquidGlassTheme.bgSurface,
                      ),
                      child: ClipOval(
                        child: hasAvatar
                            ? Image.network(
                                avatarResolved,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildInitials(user),
                              )
                            : _buildInitials(user),
                      ),
                    ),
                  ),
                ),
                // Online badge
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: user.isOnline == true ? LiquidGlassTheme.accentEmerald : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: LiquidGlassTheme.bgSurface,
                        width: 3.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Display Name
          Text(
            user.displayName.isNotEmpty ? user.displayName : user.username,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: LiquidGlassTheme.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 3),

          // Online / Last Seen Status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.isOnline == true) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LiquidGlassTheme.accentEmerald,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                lastSeenText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: user.isOnline == true ? LiquidGlassTheme.accentEmerald : LiquidGlassTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(UserModel user) {
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;
    return Container(
      color: LiquidGlassTheme.inputFill,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.outfit(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: LiquidGlassTheme.accentBlue,
          ),
        ),
      ),
    );
  }
}

class UserProfileQuickActions extends StatelessWidget {
  final UserModel user;
  final bool isMuted;
  final VoidCallback onOpenChat;
  final VoidCallback onToggleMute;
  final VoidCallback onSearch;
  final VoidCallback onMore;

  const UserProfileQuickActions({
    super.key,
    required this.user,
    required this.isMuted,
    required this.onOpenChat,
    required this.onToggleMute,
    required this.onSearch,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: CupertinoIcons.chat_bubble_fill,
            label: 'Message',
            color: LiquidGlassTheme.accentBlue,
            onTap: onOpenChat,
          ),
          _buildActionButton(
            icon: isMuted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell_fill,
            label: isMuted ? 'Muted' : 'Mute',
            color: isMuted ? Colors.amber.shade700 : LiquidGlassTheme.accentIndigo,
            onTap: onToggleMute,
          ),
          _buildActionButton(
            icon: CupertinoIcons.search,
            label: 'Search',
            color: const Color(0xFF0D9488),
            onTap: onSearch,
          ),
          _buildActionButton(
            icon: CupertinoIcons.ellipsis,
            label: 'More',
            color: LiquidGlassTheme.textSecondary,
            onTap: onMore,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
