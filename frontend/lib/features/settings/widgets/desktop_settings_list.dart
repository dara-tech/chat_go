import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/user_model.dart';

class DesktopSettingsList extends StatefulWidget {
  final UserModel currentUser;
  final String activeSection;
  final ValueChanged<String> onSelectSection;

  const DesktopSettingsList({
    super.key,
    required this.currentUser,
    required this.activeSection,
    required this.onSelectSection,
  });

  @override
  State<DesktopSettingsList> createState() => _DesktopSettingsListState();
}

class _DesktopSettingsListState extends State<DesktopSettingsList> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final primaryColor = const Color(0xFF2AABEE); // Telegram macOS vibrant blue
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    return Container(
      color: isDark ? const Color(0xFF131822) : Colors.white,
      child: Column(
        children: [
          // ── Header: QR icon + Title "Settings" + "Edit" action ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.qrcode, size: 20),
                  color: primaryColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {},
                ),
                Text(
                  'Settings',
                  style: GoogleFonts.outfit(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: LiquidGlassTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    CupertinoIcons.search,
                    size: 15,
                    color: LiquidGlassTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: LiquidGlassTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13.5,
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
            ),
          ),
          const SizedBox(height: 8),

          // ── Settings categories list ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildItem(
                  key: 'set_profile_color',
                  title: 'Set Profile Color',
                  icon: CupertinoIcons.paintbrush,
                  iconBg: const Color(0xFF06B6D4),
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'add_account',
                  title: 'Add Account',
                  icon: CupertinoIcons.person_badge_plus,
                  iconBg: const Color(0xFF3B82F6),
                  primaryColor: primaryColor,
                ),

                _buildDivider(borderColor),

                _buildItem(
                  key: 'my_profile',
                  title: 'My Profile',
                  icon: CupertinoIcons.person_crop_circle_fill,
                  iconBg: const Color(0xFFEF4444),
                  primaryColor: primaryColor,
                ),

                _buildDivider(borderColor),

                _buildItem(
                  key: 'general',
                  title: 'General',
                  icon: CupertinoIcons.gear_alt_fill,
                  iconBg: const Color(0xFF64748B),
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'notifications',
                  title: 'Notifications and Sounds',
                  icon: CupertinoIcons.bell_fill,
                  iconBg: const Color(0xFFEF4444),
                  badge: '!',
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'privacy',
                  title: 'Privacy and Security',
                  icon: CupertinoIcons.lock_fill,
                  iconBg: const Color(0xFF3B82F6),
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'data_storage',
                  title: 'Data and Storage',
                  icon: CupertinoIcons.circle_grid_hex_fill,
                  iconBg: const Color(0xFF10B981),
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'active_sessions',
                  title: 'Active Sessions',
                  icon: CupertinoIcons.device_laptop,
                  iconBg: const Color(0xFFF59E0B),
                  trailingText: '4',
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'appearance',
                  title: 'Appearance',
                  icon: CupertinoIcons.pencil,
                  iconBg: const Color(0xFF06B6D4),
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'language',
                  title: 'Language',
                  icon: CupertinoIcons.globe,
                  iconBg: const Color(0xFF8B5CF6),
                  trailingText: 'English',
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'stickers',
                  title: 'Stickers and Emoji',
                  icon: CupertinoIcons.smiley_fill,
                  iconBg: const Color(0xFFF97316),
                  primaryColor: primaryColor,
                ),
                // ── CHAT FOLDERS ITEM (Active solid blue pill when selected) ──
                _buildItem(
                  key: 'chat_folders',
                  title: 'Chat Folders',
                  icon: CupertinoIcons.folder_fill,
                  iconBg: const Color(0xFF2AABEE),
                  primaryColor: primaryColor,
                ),
                _buildItem(
                  key: 'update',
                  title: 'Update',
                  icon: CupertinoIcons.arrow_2_circlepath,
                  iconBg: const Color(0xFF3B82F6),
                  primaryColor: primaryColor,
                ),

                _buildDivider(borderColor),

                _buildItem(
                  key: 'premium',
                  title: 'Telegram Premium',
                  icon: CupertinoIcons.star_fill,
                  iconBg: const Color(0xFF8B5CF6),
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(
        height: 1,
        thickness: 0.8,
        indent: 14,
        endIndent: 14,
        color: color,
      ),
    );
  }

  Widget _buildItem({
    required String key,
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color primaryColor,
    String? trailingText,
    String? badge,
  }) {
    if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    final isSelected = widget.activeSection == key;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelectSection(key),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.2) : iconBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : LiquidGlassTheme.textPrimary,
                    ),
                  ),
                ),

                // Trailing text / badge
                if (trailingText != null)
                  Text(
                    trailingText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isSelected ? Colors.white70 : LiquidGlassTheme.textSecondary,
                    ),
                  ),
                if (badge != null)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),

                // Chevron
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 13,
                  color: isSelected ? Colors.white70 : LiquidGlassTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
