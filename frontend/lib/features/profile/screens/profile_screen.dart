import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:image_picker/image_picker.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/theme/liquid_glass_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/features/auth/screens/auth_screen.dart';
import 'package:frontend/features/profile/screens/edit_profile_screen.dart';
import 'package:frontend/features/settings/screens/chat_folders_settings_screen.dart';
import 'package:frontend/features/settings/screens/privacy_settings_screen.dart';
import 'package:frontend/features/settings/screens/theme_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const ProfileScreen({super.key, required this.currentUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _updatedUser;
  UserModel get currentUser => _updatedUser ?? widget.currentUser;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.currentUser.avatarUrl.isNotEmpty ? widget.currentUser.avatarUrl : null;
    _fetchFreshProfile();
  }

  Future<void> _fetchFreshProfile() async {
    try {
      final me = await ApiClient.instance.getMe();
      if (mounted) {
        setState(() {
          _updatedUser = me;
          if (me.avatarUrl.isNotEmpty) {
            _avatarUrl = me.avatarUrl;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          currentUser: currentUser.copyWith(
            avatarUrl: _avatarUrl ?? currentUser.avatarUrl,
          ),
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _updatedUser = updated;
        _avatarUrl = updated.avatarUrl.isNotEmpty ? updated.avatarUrl : null;
      });
    } else if (mounted) {
      _fetchFreshProfile();
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      final bytes = await picked.readAsBytes();
      final filename = picked.name;

      final newUrl = await ApiClient.instance.uploadAvatar(
        bytes: bytes,
        filename: filename,
      );

      if (mounted) {
        setState(() {
          _avatarUrl = newUrl;
          _updatedUser = currentUser.copyWith(avatarUrl: newUrl);
          _isUploadingAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _showAvatarOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text(
          'Change Profile Photo',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndUploadAvatar(ImageSource.gallery);
            },
            child: const Text('Choose from Library'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndUploadAvatar(ImageSource.camera);
            },
            child: const Text('Take Photo'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: LiquidGlassTheme.bgCard,
        title: Text(
          'Sign Out',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: LiquidGlassTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to log out of ChatGo?',
          style: GoogleFonts.inter(fontSize: 14, color: LiquidGlassTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: LiquidGlassTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiClient.instance.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return Column(
          children: [
            // 1. Top Bar Header
            _buildTopHeader(context),

            // 2. Profile Content (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                child: Column(
                  children: [
                    // Hero Avatar & User Info
                    _buildHeroProfile(context),
                    const SizedBox(height: 24),

                    // Section: Appearance & Theme
                    _buildSectionHeader('APPEARANCE & THEME'),
                    _buildAppearanceGroup(context),
                    const SizedBox(height: 20),

                    // Section: Account
                    _buildSectionHeader('ACCOUNT'),
                    _buildAccountGroup(),
                    const SizedBox(height: 20),

                    // Section: Services & Storage
                    _buildSectionHeader('SERVICES & STORAGE'),
                    _buildServicesGroup(context),
                    const SizedBox(height: 20),

                    // Section: Danger Zone / Sign Out
                    _buildSectionHeader('SESSION'),
                    _buildSessionGroup(context),
                    const SizedBox(height: 24),

                    // Version Footer
                    Text(
                      'ChatGo v1.0.0 • Go & Flutter Architecture',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: LiquidGlassTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Profile',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: LiquidGlassTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.qrcode,
                    size: 17,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openEditProfile,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.pencil,
                    size: 17,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroProfile(BuildContext context) {
    final displayName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.username;
    final initial = currentUser.username.isNotEmpty
        ? currentUser.username[0].toUpperCase()
        : 'U';

    return Column(
      children: [
        // Avatar with Camera Badge
        Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: ThemeController.instance.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: _isUploadingAvatar
                  ? const Center(
                      child: CupertinoActivityIndicator(
                        color: Colors.white,
                        radius: 14,
                      ),
                    )
                  : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            ApiClient.resolveAvatarUrl(_avatarUrl),
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.outfit(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _showAvatarOptions,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.bgCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 1.5),
                  ),
                  child: Icon(
                    CupertinoIcons.camera_fill,
                    size: 14,
                    color: LiquidGlassTheme.accentBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Display Name + Verified Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayName,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: LiquidGlassTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              CupertinoIcons.checkmark_seal_fill,
              size: 18,
              color: LiquidGlassTheme.accentBlue,
            ),
          ],
        ),
        const SizedBox(height: 3),

        // Username
        Text(
          '@${currentUser.username}',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: LiquidGlassTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Active Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: LiquidGlassTheme.accentEmerald.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: LiquidGlassTheme.accentEmerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Active on ChatGo',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: LiquidGlassTheme.accentEmerald,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: LiquidGlassTheme.textMuted,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceGroup(BuildContext context) {
    final currentTheme = ThemeController.instance.current;
    final currentBg = ThemeController.instance.bgPreset;
    final showAvatar = ThemeController.instance.showAvatarInChat;

    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LiquidGlassTheme.borderSubtle),
      ),
      child: Column(
        children: [
          _buildGroupRow(
            icon: CupertinoIcons.paintbrush_fill,
            iconBg: ThemeController.instance.primaryColor,
            title: 'Theme & Appearance',
            subtitle: '${currentTheme.name} • ${currentBg.name} • ${ThemeController.instance.bubbleStyle.name}',
            showChevron: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ThemeSettingsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, thickness: 0.8, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildGroupRow(
            icon: CupertinoIcons.folder_fill,
            iconBg: const Color(0xFF0284C7),
            title: 'Chat Folders',
            subtitle: 'Organize chats into custom folders & tabs',
            showChevron: true,
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const ChatFoldersSettingsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, thickness: 0.8, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildGroupRow(
            icon: CupertinoIcons.person_crop_circle,
            iconBg: const Color(0xFF6366F1),
            title: 'Show Profile Bubble',
            subtitle: 'Display avatar next to messages in chat',
            trailingWidget: CupertinoSwitch(
              value: showAvatar,
              activeColor: ThemeController.instance.primaryColor,
              onChanged: (val) {
                ThemeController.instance.setShowAvatarInChat(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountGroup() {
    final createdDate =
        '${currentUser.createdAt.day.toString().padLeft(2, '0')}/${currentUser.createdAt.month.toString().padLeft(2, '0')}/${currentUser.createdAt.year}';

    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LiquidGlassTheme.borderSubtle),
      ),
      child: Column(
        children: [
          _buildGroupRow(
            icon: CupertinoIcons.mail_solid,
            iconBg: const Color(0xFF2563EB),
            title: 'Email',
            value: currentUser.email,
          ),
          Divider(height: 1, thickness: 0.8, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildGroupRow(
            icon: CupertinoIcons.at,
            iconBg: const Color(0xFF7C3AED),
            title: 'Username',
            value: '@${currentUser.username}',
          ),
          Divider(height: 1, thickness: 0.8, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildGroupRow(
            icon: CupertinoIcons.number,
            iconBg: const Color(0xFF0284C7),
            title: 'User ID',
            value: '#${currentUser.id}',
          ),
          Divider(height: 1, thickness: 0.8, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildGroupRow(
            icon: CupertinoIcons.calendar,
            iconBg: const Color(0xFF059669),
            title: 'Member Since',
            value: createdDate,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGroup(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LiquidGlassTheme.borderSubtle),
      ),
      child: Column(
        children: [
          _buildGroupRow(
            icon: CupertinoIcons.cloud_upload_fill,
            iconBg: const Color(0xFFEA580C),
            title: 'Cloudflare R2 Storage',
            subtitle: 'Direct high-speed media hosting',
            trailingWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Active',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.8, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildGroupRow(
            icon: CupertinoIcons.bolt_horizontal_circle_fill,
            iconBg: const Color(0xFF2563EB),
            title: 'WebSocket Live Hub',
            subtitle: 'Instant bi-directional real-time chat',
            trailingWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Connected',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.8, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildGroupRow(
            icon: CupertinoIcons.shield_lefthalf_fill,
            iconBg: const Color(0xFF0D9488),
            title: 'Security & Privacy',
            subtitle: 'GPS location, encryption & privacy',
            showChevron: true,
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionGroup(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _handleLogout(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    String? value,
    Widget? trailingWidget,
    bool showChevron = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Squircle Icon Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: LiquidGlassTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: LiquidGlassTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Value / Trailing
              if (value != null)
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),

              ?trailingWidget,

              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: LiquidGlassTheme.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
