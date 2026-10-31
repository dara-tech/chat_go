import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/liquid_glass_theme.dart';
import '../../../models/user_model.dart';

class UserProfileInfoCard extends StatelessWidget {
  final UserModel user;
  final Function(String text, String label) onCopy;

  const UserProfileInfoCard({
    super.key,
    required this.user,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Column(
        children: [
          // Bio / About
          _buildInfoTile(
            icon: CupertinoIcons.info_circle_fill,
            title: 'Bio',
            subtitle: 'Available on ChatGo Messenger. Active real-time peer.',
            iconColor: LiquidGlassTheme.accentBlue,
            canCopy: false,
          ),
          Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),

          // Username
          _buildInfoTile(
            icon: CupertinoIcons.at,
            title: '@${user.username}',
            subtitle: 'Username (tap to copy)',
            iconColor: LiquidGlassTheme.accentIndigo,
            canCopy: true,
            copyText: user.username,
            copyLabel: 'Username',
          ),
          Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),

          // User ID
          _buildInfoTile(
            icon: CupertinoIcons.number,
            title: '#${user.id}',
            subtitle: 'Account ID',
            iconColor: const Color(0xFF0D9488),
            canCopy: true,
            copyText: '${user.id}',
            copyLabel: 'User ID',
          ),
          Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),

          // Member since
          _buildInfoTile(
            icon: CupertinoIcons.calendar,
            title: 'Member Since',
            subtitle: '${user.createdAt.month}/${user.createdAt.year}',
            iconColor: const Color(0xFFF59E0B),
            canCopy: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required bool canCopy,
    String? copyText,
    String? copyLabel,
  }) {
    return InkWell(
      onTap: canCopy && copyText != null ? () => onCopy(copyText, copyLabel ?? 'Text') : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: LiquidGlassTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: LiquidGlassTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (canCopy)
              Icon(
                CupertinoIcons.doc_on_doc,
                size: 16,
                color: LiquidGlassTheme.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
