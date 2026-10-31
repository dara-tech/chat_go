import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/core/theme/liquid_glass_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const EditProfileScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  TextEditingController? _localDisplayNameController;
  TextEditingController? _localUsernameController;
  TextEditingController get _displayNameController =>
      _localDisplayNameController ??= TextEditingController(text: widget.currentUser.displayName);
  TextEditingController get _usernameController =>
      _localUsernameController ??= TextEditingController(text: widget.currentUser.username);
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isSaving = false;

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
          if (me.avatarUrl.isNotEmpty) {
            _avatarUrl = me.avatarUrl;
          }
          if (_displayNameController.text.isEmpty && me.displayName.isNotEmpty) {
            _displayNameController.text = me.displayName;
          }
          if (_usernameController.text.isEmpty && me.username.isNotEmpty) {
            _usernameController.text = me.username;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _localDisplayNameController?.dispose();
    _localUsernameController?.dispose();
    super.dispose();
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

  Future<void> _handleSave() async {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (username.isEmpty) {
      return;
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
    if (!usernameRegex.hasMatch(username)) {
      return;
    }

    final hasChanges = displayName != widget.currentUser.displayName ||
        username != widget.currentUser.username ||
        _avatarUrl != widget.currentUser.avatarUrl;

    if (!hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await ApiClient.instance.updateProfile(
        displayName: displayName,
        username: username,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.currentUser.username.isNotEmpty
        ? widget.currentUser.username[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: LiquidGlassTheme.bgScaffold,
      appBar: AppBar(
        backgroundColor: LiquidGlassTheme.bgScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 76,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: LiquidGlassTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: LiquidGlassTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isSaving
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoActivityIndicator(radius: 9),
                    ),
                  )
                : CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: _handleSave,
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: LiquidGlassTheme.accentBlue,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Avatar with camera action
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showAvatarOptions,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: ThemeController.instance.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: _isUploadingAvatar
                                ? const Center(
                                    child: CupertinoActivityIndicator(
                                      color: Colors.white,
                                      radius: 16,
                                    ),
                                  )
                                : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          ApiClient.resolveAvatarUrl(_avatarUrl),
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Center(
                                            child: Text(
                                              initial,
                                              style: GoogleFonts.outfit(
                                                fontSize: 42,
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
                                            fontSize: 42,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: LiquidGlassTheme.accentBlue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: LiquidGlassTheme.bgScaffold,
                                  width: 2.5,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.camera_fill,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showAvatarOptions,
                      child: Text(
                        'Set New Photo',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: LiquidGlassTheme.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Telegram-style Info Card (Display Name & Username)
              Container(
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
                ),
                child: Column(
                  children: [
                    // Display Name Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Display Name',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: LiquidGlassTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _displayNameController,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: LiquidGlassTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Your name',
                                hintStyle: GoogleFonts.inter(
                                  color: LiquidGlassTheme.textMuted,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.8,
                      indent: 16,
                      color: LiquidGlassTheme.dividerHairline,
                    ),
                    // Username Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Username',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: LiquidGlassTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '@',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: LiquidGlassTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: LiquidGlassTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'username',
                                hintStyle: GoogleFonts.inter(
                                  color: LiquidGlassTheme.textMuted,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Helper caption
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'You can choose a username on ChatGo. Other users will be able to find and chat with you by this username.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: LiquidGlassTheme.textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Secondary Card: Read-only Account Info
              Container(
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Email',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: LiquidGlassTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.currentUser.email,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: LiquidGlassTheme.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            CupertinoIcons.lock_fill,
                            size: 14,
                            color: LiquidGlassTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your email is verified and permanently linked to this account.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: LiquidGlassTheme.textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
