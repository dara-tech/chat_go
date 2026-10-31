import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/storage/local_chat_storage.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../models/user_model.dart';
import '../../chat/screens/chat_screen.dart';
import '../../media/screens/media_viewer_screen.dart';
import '../widgets/user_profile_hero.dart';
import '../widgets/user_profile_info_card.dart';
import 'shared_media_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  final UserModel? initialUser;
  final UserModel? currentUser;
  final bool fromChatScreen;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialUser,
    this.currentUser,
    this.fromChatScreen = false,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isMuted = false;
  List<Map<String, dynamic>> _mediaItems = [];
  List<Map<String, dynamic>> _fileItems = [];
  List<Map<String, dynamic>> _linkItems = [];
  bool _isLoadingSharedContent = true;

  @override
  void initState() {
    super.initState();
    _checkMuteStatus();
    _loadSharedContent();
  }

  Future<void> _loadSharedContent() async {
    // 1. Instant load from local cached messages (0ms)
    try {
      final cached = await LocalChatStorage.instance.getCachedMessages(widget.userId);
      if (cached.isNotEmpty) {
        _categorizeMessages(cached);
      }
    } catch (_) {}

    // 2. Fetch latest shared media from authorized backend API
    try {
      final remote = await ApiClient.instance.getSharedMedia(widget.userId);
      if (mounted) {
        _categorizeMessages(remote);
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() {
          _isLoadingSharedContent = false;
        });
      }
    }
  }

  void _categorizeMessages(List<Map<String, dynamic>> messages) {
    final media = <Map<String, dynamic>>[];
    final files = <Map<String, dynamic>>[];
    final links = <Map<String, dynamic>>[];
    final seenLinkUrls = <String>{};

    for (final m in messages) {
      final mediaType = (m['media_type'] as String? ?? 'text').toLowerCase();
      final mediaUrl = (m['media_url'] as String? ?? '').trim();
      final content = (m['content'] as String? ?? '').trim();

      // Strictly exclude any mockup / dummy / placeholder media
      if (mediaUrl.contains('unsplash.com') ||
          mediaUrl.contains('chatgo.dev') ||
          mediaUrl.contains('placeholder') ||
          mediaUrl.contains('dummyimage') ||
          content.contains('unsplash.com') ||
          content.contains('chatgo.dev')) {
        continue;
      }

      // Photos & Videos
      if ((mediaType == 'image' || mediaType == 'photo' || mediaType == 'video') && mediaUrl.isNotEmpty) {
        media.add(m);
      }
      // Files, Documents & Voice
      else if (mediaType == 'file' || mediaType == 'voice' || mediaType == 'audio' || mediaType == 'document') {
        files.add(m);
      }
      // Links
      if (content.contains('http://') || content.contains('https://')) {
        final regExp = RegExp(r'(https?://[^\s]+)');
        final matches = regExp.allMatches(content);
        for (final match in matches) {
          final url = match.group(0);
          if (url != null && !seenLinkUrls.contains(url)) {
            seenLinkUrls.add(url);
            links.add({
              'url': url,
              'content': content,
              'timestamp': m['timestamp'] ?? m['created_at'],
              'sender_id': m['sender_id'],
            });
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _mediaItems = media;
        _fileItems = files;
        _linkItems = links;
      });
    }
  }

  Future<void> _checkMuteStatus() async {
    final convId = 'chat_${widget.userId}';
    final convs = await LocalChatStorage.instance.getCachedConversations();
    final match = convs.where((c) => c.conversationId == convId || c.user.id == widget.userId);
    if (match.isNotEmpty && mounted) {
      setState(() {
        _isMuted = match.first.isMuted;
      });
    }
  }

  Future<void> _toggleMute() async {
    final convId = 'chat_${widget.userId}';
    await LocalChatStorage.instance.toggleMute(convId);
    if (mounted) {
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  void _openChat(UserModel profile) {
    if (widget.fromChatScreen) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.currentUser != null) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (_) => ChatScreen(
            currentUser: widget.currentUser!,
            chatUser: profile,
            title: profile.displayName.isNotEmpty ? profile.displayName : profile.username,
          ),
        ),
      );
    }
  }

  void _openAvatarViewer(String avatarUrl, String displayName) {
    if (avatarUrl.isEmpty) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MediaViewerScreen(
          items: [
            MediaViewerItem(
              id: 'avatar_${widget.userId}',
              mediaUrl: ApiClient.resolveAvatarUrl(avatarUrl),
              senderName: displayName,
              timestamp: DateTime.now(),
              caption: 'Profile photo of $displayName',
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard', style: GoogleFonts.inter(fontSize: 13)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: LiquidGlassTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatLastSeen(UserModel user) {
    if (user.isOnline == true) return 'Online';
    if (user.lastSeenAt == null) return 'Last seen recently';
    final diff = DateTime.now().difference(user.lastSeenAt!);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Last seen ${diff.inDays}d ago';
    return 'Last seen on ${user.lastSeenAt!.month}/${user.lastSeenAt!.day}/${user.lastSeenAt!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider(widget.userId));
    final user = profileState.profile ?? widget.initialUser;

    return Scaffold(
      backgroundColor: LiquidGlassTheme.bgSurface,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            right: -40,
            height: 340,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.1,
                  colors: [
                    LiquidGlassTheme.accentBlue.withOpacity(LiquidGlassTheme.isDark ? 0.15 : 0.08),
                    LiquidGlassTheme.bgSurface.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(profileState),
                Expanded(
                  child: user == null && profileState.isSyncing
                      ? _buildInitialLoadingShimmer()
                      : user == null
                          ? _buildNotFoundView()
                          : RefreshIndicator(
                              onRefresh: () async {
                                await Future.wait([
                                  ref.read(profileNotifierProvider(widget.userId).notifier).refresh(),
                                  _loadSharedContent(),
                                ]);
                              },
                              color: LiquidGlassTheme.accentBlue,
                              backgroundColor: LiquidGlassTheme.bgCard,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                children: [
                                  _buildSubtleSyncIndicator(profileState),
                                  UserProfileHero(
                                    user: user,
                                    lastSeenText: _formatLastSeen(user),
                                    onOpenAvatar: () => _openAvatarViewer(user.avatarUrl, user.displayName),
                                  ),
                                  const SizedBox(height: 18),
                                  UserProfileQuickActions(
                                    user: user,
                                    isMuted: _isMuted,
                                    onOpenChat: () => _openChat(user),
                                    onToggleMute: _toggleMute,
                                    onSearch: () {
                                      _openChat(user);
                                    },
                                    onMore: _showMoreSheet,
                                  ),
                                  const SizedBox(height: 20),
                                  UserProfileInfoCard(
                                    user: user,
                                    onCopy: _copyToClipboard,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildActionsCard(user),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ProfileDataState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.inputFill,
                shape: BoxShape.circle,
                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                size: 18,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
          ),
          Text(
            'User Profile',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: LiquidGlassTheme.textPrimary,
            ),
          ),
          GestureDetector(
            onTap: _showMoreSheet,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.inputFill,
                shape: BoxShape.circle,
                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
              ),
              child: Icon(
                CupertinoIcons.ellipsis,
                size: 18,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtleSyncIndicator(ProfileDataState state) {
    if (!state.isSyncing && !state.isOffline) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: state.isSyncing
                ? LiquidGlassTheme.accentBlue.withOpacity(0.12)
                : Colors.amber.shade800.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isSyncing) ...[
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(LiquidGlassTheme.accentBlue),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Syncing latest profile...',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: LiquidGlassTheme.accentBlue),
                ),
              ] else if (state.isOffline) ...[
                Icon(CupertinoIcons.cloud_bolt_rain_fill, size: 12, color: Colors.amber.shade800),
                const SizedBox(width: 6),
                Text(
                  'Offline cached profile',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.amber.shade800),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openSharedMediaScreen(UserModel user) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SharedMediaScreen(
          user: user,
          mediaItems: _mediaItems,
          fileItems: _fileItems,
          linkItems: _linkItems,
          onRefresh: _loadSharedContent,
        ),
        ),
    );
  }



  Widget _buildActionsCard(UserModel user) {
    final totalSharedCount = _mediaItems.length + _fileItems.length + _linkItems.length;

    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Column(
        children: [
          _buildActionRow(
            icon: CupertinoIcons.photo_on_rectangle,
            iconColor: LiquidGlassTheme.accentBlue,
            title: 'Media, Files & Links',
            trailingText: _isLoadingSharedContent
                ? '...'
                : (totalSharedCount > 0 ? '$totalSharedCount' : null),
            onTap: () => _openSharedMediaScreen(user),
          ),
          Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildActionRow(
            icon: CupertinoIcons.share,
            title: 'Share Contact Card',
            onTap: () => _copyToClipboard(
              'ChatGo Contact: ${user.displayName} (@${user.username}) ID: ${user.id}',
              'Contact card',
            ),
          ),
          Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildActionRow(
            icon: CupertinoIcons.nosign,
            title: 'Block User',
            titleColor: const Color(0xFFEF4444),
            onTap: () => _confirmBlockUser(user),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    String? trailingText,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final effectiveColor = iconColor ?? (titleColor ?? LiquidGlassTheme.textPrimary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: effectiveColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? LiquidGlassTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: LiquidGlassTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null && trailingText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailingText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: LiquidGlassTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Profile Options'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleMute();
            },
            child: Text(_isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(profileNotifierProvider(widget.userId).notifier).refresh();
            },
            child: const Text('Force Sync with Server'),
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

  void _confirmBlockUser(UserModel user) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Block ${user.displayName}?'),
        content: const Text(
          'Blocked users will not be able to send you messages or view your online status.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.displayName} has been blocked'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialLoadingShimmer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(LiquidGlassTheme.accentBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Reading local profile...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: LiquidGlassTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.person_badge_minus, size: 48, color: LiquidGlassTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            'User profile not found',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: LiquidGlassTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
