import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/local_chat_storage.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/websocket/chat_socket_service.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../../media/screens/media_viewer_screen.dart';
import '../../profile/screens/shared_media_screen.dart';
import '../../profile/screens/user_profile_screen.dart';

/// Entry point that opens the modern Group Profile / Info screen,
/// fully matching the aesthetics, radial gradients, glass cards,
/// and design language of [UserProfileScreen].
class GroupInfoSheet {
  static Future<bool?> show({
    required BuildContext context,
    required ChatGroup initialGroup,
    required UserModel currentUser,
    required Function(ChatGroup updatedGroup) onGroupUpdated,
  }) async {
    HapticFeedback.mediumImpact();

    return Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => GroupInfoScreen(
          initialGroup: initialGroup,
          currentUser: currentUser,
          onGroupUpdated: onGroupUpdated,
        ),
      ),
    );
  }
}

class GroupInfoScreen extends StatefulWidget {
  final ChatGroup initialGroup;
  final UserModel currentUser;
  final Function(ChatGroup updatedGroup) onGroupUpdated;

  const GroupInfoScreen({
    super.key,
    required this.initialGroup,
    required this.currentUser,
    required this.onGroupUpdated,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late ChatGroup _group;
  bool _isMuted = false;
  bool _isLoading = false;
  bool _isUpdatingAvatar = false;
  bool _isLoadingSharedContent = true;

  List<Map<String, dynamic>> _mediaItems = [];
  List<Map<String, dynamic>> _fileItems = [];
  List<Map<String, dynamic>> _linkItems = [];

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _checkMuteStatus();
    _refreshGroup();
    _loadSharedContent();
  }

  Future<void> _refreshGroup() async {
    try {
      final fresh = await ApiClient.instance.getGroup(_group.id);
      if (mounted) {
        setState(() => _group = fresh);
        widget.onGroupUpdated(fresh);
      }
    } catch (_) {}
  }

  Future<void> _checkMuteStatus() async {
    final convId = 'group_${_group.id}';
    final convs = await LocalChatStorage.instance.getCachedConversations();
    final match = convs.where((c) => c.conversationId == convId);
    if (match.isNotEmpty && mounted) {
      setState(() {
        _isMuted = match.first.isMuted;
      });
    }
  }

  Future<void> _toggleMute() async {
    final convId = 'group_${_group.id}';
    await LocalChatStorage.instance.toggleMute(convId);
    if (mounted) {
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  Future<void> _loadSharedContent() async {
    // 1. Instant load from local cache
    try {
      final cached = await LocalChatStorage.instance.getCachedMessages(_group.id);
      if (cached.isNotEmpty) {
        _categorizeMessages(cached);
      }
    } catch (_) {}

    // 2. Fetch fresh group messages from backend
    try {
      final msgs = await ApiClient.instance.getGroupMessages(_group.id, limit: 100);
      final rawMaps = msgs.map((m) => m.toJson()).toList();
      if (mounted) {
        _categorizeMessages(rawMaps);
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _isLoadingSharedContent = false);
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
      // Files & Audio
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
              'username': m['username'] ?? m['sender_name'],
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

  void _openAvatarViewer() {
    if (_group.avatarUrl.isEmpty) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MediaViewerScreen(
          items: [
            MediaViewerItem(
              id: 'group_avatar_${_group.id}',
              mediaUrl: ApiClient.resolveAvatarUrl(_group.avatarUrl),
              senderName: _group.name,
              timestamp: _group.createdAt,
              caption: 'Group photo of ${_group.name}',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final isCreator = _group.creatorId == widget.currentUser.id;
    final isAdmin = isCreator ||
        _group.members.any((m) => m.userId == widget.currentUser.id && m.isAdmin);

    if (!isAdmin) {
      _openAvatarViewer();
      return;
    }

    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(_group.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          if (_group.avatarUrl.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openAvatarViewer();
              },
              child: const Text('View Photo'),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (picked == null) return;

                setState(() => _isUpdatingAvatar = true);
                final bytes = await picked.readAsBytes();
                final url = await ApiClient.instance.uploadChatMedia(
                  bytes: bytes,
                  filename: picked.name,
                );
                final updated = await ApiClient.instance.updateGroup(_group.id, avatarUrl: url);
                if (mounted) {
                  setState(() {
                    _group = updated;
                    _isUpdatingAvatar = false;
                  });
                  widget.onGroupUpdated(updated);
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isUpdatingAvatar = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update photo: $e')),
                  );
                }
              }
            },
            child: const Text('Choose New Photo'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _editGroupDetails() async {
    final nameCtrl = TextEditingController(text: _group.name);
    final descCtrl = TextEditingController(text: _group.description);

    final saved = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Edit Group Info'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: nameCtrl,
              placeholder: 'Group Name',
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: descCtrl,
              placeholder: 'Description (optional)',
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final updated = await ApiClient.instance.updateGroup(
          _group.id,
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
        );
        if (mounted) {
          setState(() => _group = updated);
          widget.onGroupUpdated(updated);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update group: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleAddMembers() async {
    final existingMemberIds = _group.members.map((m) => m.userId).toSet();
    existingMemberIds.add(widget.currentUser.id);

    try {
      final allUsers = await ApiClient.instance.listUsers(limit: 100);
      final eligible = allUsers.where((u) => !existingMemberIds.contains(u.id)).toList();

      if (!mounted) return;

      if (eligible.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All contacts are already in this group')),
        );
        return;
      }

      final Set<int> selectedIds = {};
      final added = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              final surface = isDark ? const Color(0xFF1E2430) : const Color(0xFFF8FAFC);

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text('Cancel', style: GoogleFonts.inter(color: LiquidGlassTheme.textMuted)),
                          ),
                          Text('Add Members', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: LiquidGlassTheme.textPrimary)),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: selectedIds.isEmpty
                                ? null
                                : () async {
                                    try {
                                      final nav = Navigator.of(ctx);
                                      await ApiClient.instance.addGroupMembers(_group.id, selectedIds.toList());
                                      nav.pop(true);
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text('Failed adding members: $e')),
                                        );
                                      }
                                    }
                                  },
                            child: Text('Add', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: LiquidGlassTheme.accentBlue)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: eligible.length,
                        itemBuilder: (ctx, idx) {
                          final user = eligible[idx];
                          final isSel = selectedIds.contains(user.id);
                          return CupertinoListTile(
                            onTap: () {
                              setModalState(() {
                                if (isSel) {
                                  selectedIds.remove(user.id);
                                } else {
                                  selectedIds.add(user.id);
                                }
                              });
                            },
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundImage: user.avatarUrl.isNotEmpty
                                  ? NetworkImage(ApiClient.resolveAvatarUrl(user.avatarUrl))
                                  : null,
                              child: user.avatarUrl.isEmpty
                                  ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U')
                                  : null,
                            ),
                            title: Text(user.displayName, style: GoogleFonts.inter(fontSize: 14.5, color: LiquidGlassTheme.textPrimary)),
                            subtitle: Text('@${user.username}', style: GoogleFonts.inter(fontSize: 12, color: LiquidGlassTheme.textMuted)),
                            trailing: isSel
                                ? Icon(CupertinoIcons.checkmark_circle_fill, color: LiquidGlassTheme.accentBlue)
                                : const Icon(CupertinoIcons.circle, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (added == true) {
        _refreshGroup();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load contacts: $e')),
        );
      }
    }
  }

  void _showMemberOptions(GroupMember member) {
    final name = member.user?.displayName.isNotEmpty == true
        ? member.user!.displayName
        : 'Member #${member.userId}';

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (member.user != null) {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: member.user!.id,
                      initialUser: member.user,
                      currentUser: widget.currentUser,
                    ),
                  ),
                );
              }
            },
            child: const Text('View Profile'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ApiClient.instance.removeGroupMember(_group.id, member.userId);
                _refreshGroup();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove member: $e')),
                  );
                }
              }
            },
            child: const Text('Remove from Group'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _handleLeaveGroup() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Leave Group'),
        content: Text('Are you sure you want to leave "${_group.name}"?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiClient.instance.leaveGroup(_group.id);
      if (mounted) {
        Navigator.of(context).pop(true); // Return true = user left group
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
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

  void _openSharedMediaScreen() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SharedMediaScreen(
          title: _group.name,
          mediaItems: _mediaItems,
          fileItems: _fileItems,
          linkItems: _linkItems,
          onRefresh: _loadSharedContent,
        ),
      ),
    );
  }

  void _showMoreSheet() {
    final isCreator = _group.creatorId == widget.currentUser.id;
    final isAdmin = isCreator ||
        _group.members.any((m) => m.userId == widget.currentUser.id && m.isAdmin);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(_group.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          if (isAdmin) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _editGroupDetails();
              },
              child: const Text('Edit Group Details'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickAndUploadAvatar();
              },
              child: const Text('Change Group Photo'),
            ),
          ],
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleAddMembers();
            },
            child: const Text('Add Members'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _copyToClipboard(
                'https://chatgo.app/join/group/${_group.id}',
                'Group invite link',
              );
            },
            child: const Text('Copy Invite Link'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleLeaveGroup();
            },
            child: const Text('Leave Group'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ChatSocketService.instance.connectionStateNotifier,
        ChatSocketService.instance.onlineUserIdsNotifier,
      ]),
      builder: (context, _) {
        int onlineCount = 0;
        for (final m in _group.members) {
          final isOnline = m.user != null &&
              (ChatSocketService.instance.isUserOnline(m.userId) || m.user!.isOnline == true);
          if (isOnline) onlineCount++;
        }

        return Scaffold(
          backgroundColor: LiquidGlassTheme.bgSurface,
          body: Stack(
            children: [
              // Top ambient glow radial gradient (identical to UserProfileScreen)
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
                    _buildTopBar(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await Future.wait([
                            _refreshGroup(),
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
                            _buildHero(onlineCount),
                            const SizedBox(height: 18),
                            _buildQuickActions(),
                            const SizedBox(height: 20),
                            _buildInfoCard(),
                            const SizedBox(height: 16),
                            _buildActionsCard(),
                            const SizedBox(height: 20),
                            _buildMembersCard(),
                            const SizedBox(height: 20),
                            _buildDangerActionsCard(),
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
      },
    );
  }

  Widget _buildTopBar() {
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
            'Group Info',
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

  Widget _buildHero(int onlineCount) {
    final avatarResolved = ApiClient.resolveAvatarUrl(_group.avatarUrl);
    final hasAvatar = _group.avatarUrl.isNotEmpty;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickAndUploadAvatar,
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
                        child: _isUpdatingAvatar
                            ? const Center(child: CupertinoActivityIndicator())
                            : hasAvatar
                                ? Image.network(
                                    avatarResolved,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildInitials(),
                                  )
                                : _buildInitials(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: LiquidGlassTheme.accentBlue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: LiquidGlassTheme.bgSurface,
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _group.name,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: LiquidGlassTheme.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onlineCount > 0) ...[
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
                '${_group.members.length} members${onlineCount > 0 ? ' • $onlineCount online' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: onlineCount > 0
                      ? LiquidGlassTheme.accentEmerald
                      : LiquidGlassTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitials() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.person_2_fill,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
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
            onTap: () => Navigator.of(context).pop(),
          ),
          _buildActionButton(
            icon: _isMuted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell_fill,
            label: _isMuted ? 'Muted' : 'Mute',
            color: _isMuted ? Colors.amber.shade700 : LiquidGlassTheme.accentIndigo,
            onTap: _toggleMute,
          ),
          _buildActionButton(
            icon: CupertinoIcons.person_badge_plus,
            label: 'Add',
            color: LiquidGlassTheme.accentEmerald,
            onTap: _handleAddMembers,
          ),
          _buildActionButton(
            icon: CupertinoIcons.search,
            label: 'Search',
            color: const Color(0xFF0D9488),
            onTap: () => Navigator.of(context).pop(),
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

  Widget _buildInfoCard() {
    final creator = _group.members.firstWhere(
      (m) => m.userId == _group.creatorId,
      orElse: () => _group.members.isNotEmpty
          ? _group.members.first
          : GroupMember(id: 0, groupId: _group.id, userId: _group.creatorId, joinedAt: _group.createdAt),
    );
    final creatorName = creator.user?.displayName.isNotEmpty == true
        ? creator.user!.displayName
        : 'Member #${_group.creatorId}';

    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Column(
        children: [
          if (_group.description.isNotEmpty) ...[
            _buildInfoTile(
              icon: CupertinoIcons.info_circle_fill,
              title: 'Description',
              subtitle: _group.description,
              iconColor: LiquidGlassTheme.accentBlue,
              canCopy: true,
              copyText: _group.description,
              copyLabel: 'Group description',
            ),
            Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),
          ],
          _buildInfoTile(
            icon: CupertinoIcons.number,
            title: '#group_${_group.id}',
            subtitle: 'Group ID (tap to copy)',
            iconColor: const Color(0xFF0D9488),
            canCopy: true,
            copyText: '${_group.id}',
            copyLabel: 'Group ID',
          ),
          Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildInfoTile(
            icon: CupertinoIcons.calendar,
            title: 'Created by $creatorName',
            subtitle: '${_group.createdAt.month}/${_group.createdAt.day}/${_group.createdAt.year}',
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
      onTap: canCopy && copyText != null ? () => _copyToClipboard(copyText, copyLabel ?? 'Text') : null,
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

  Widget _buildActionsCard() {
    final totalSharedCount = _mediaItems.length + _fileItems.length + _linkItems.length;
    final isCreator = _group.creatorId == widget.currentUser.id;
    final isAdmin = isCreator ||
        _group.members.any((m) => m.userId == widget.currentUser.id && m.isAdmin);

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
            onTap: _openSharedMediaScreen,
          ),
          Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),
          _buildActionRow(
            icon: CupertinoIcons.share,
            title: 'Share Group Invite Link',
            onTap: () => _copyToClipboard(
              'https://chatgo.app/join/group/${_group.id}',
              'Group invite link',
            ),
          ),
          if (isAdmin) ...[
            Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),
            _buildActionRow(
              icon: CupertinoIcons.pencil,
              iconColor: LiquidGlassTheme.accentIndigo,
              title: 'Edit Group Info',
              onTap: _editGroupDetails,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEMBERS (${_group.members.length})',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: LiquidGlassTheme.textMuted,
                ),
              ),
              GestureDetector(
                onTap: _handleAddMembers,
                child: Text(
                  '+ Add Members',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LiquidGlassTheme.accentBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: LiquidGlassTheme.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _group.members.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 64, color: LiquidGlassTheme.dividerHairline),
            itemBuilder: (context, idx) {
              final member = _group.members[idx];
              final u = member.user;
              final name = u?.displayName.isNotEmpty == true ? u!.displayName : 'Member #${member.userId}';
              final username = u?.username.isNotEmpty == true ? '@${u!.username}' : '';
              final isCreator = member.userId == _group.creatorId;
              final isAdmin = member.isAdmin || isCreator;
              final isMe = member.userId == widget.currentUser.id;

              final isOnline = u != null &&
                  (ChatSocketService.instance.isUserOnline(u.id) || u.isOnline == true);

              return InkWell(
                onTap: () {
                  if (u != null) {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => UserProfileScreen(
                          userId: u.id,
                          initialUser: u,
                          currentUser: widget.currentUser,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: LiquidGlassTheme.accentBlue.withOpacity(0.12),
                            backgroundImage: (u?.avatarUrl.isNotEmpty == true)
                                ? NetworkImage(ApiClient.resolveAvatarUrl(u!.avatarUrl))
                                : null,
                            child: (u?.avatarUrl.isEmpty ?? true)
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: LiquidGlassTheme.accentBlue,
                                    ),
                                  )
                                : null,
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: LiquidGlassTheme.accentEmerald,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: LiquidGlassTheme.bgCard,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isMe ? '$name (You)' : name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: LiquidGlassTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isCreator
                                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                                          : LiquidGlassTheme.accentBlue.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isCreator ? 'Owner' : 'Admin',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isCreator ? const Color(0xFFD97706) : LiquidGlassTheme.accentBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (username.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                username,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: LiquidGlassTheme.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isMe &&
                          (_group.creatorId == widget.currentUser.id ||
                              (_group.members.any((m) => m.userId == widget.currentUser.id && m.isAdmin) && !isCreator)))
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 32,
                          onPressed: () => _showMemberOptions(member),
                          child: Icon(
                            CupertinoIcons.ellipsis,
                            size: 16,
                            color: LiquidGlassTheme.textSecondary,
                          ),
                        )
                      else
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 15,
                          color: LiquidGlassTheme.textSecondary.withOpacity(0.5),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDangerActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Column(
        children: [
          _buildActionRow(
            icon: CupertinoIcons.square_arrow_right,
            iconColor: const Color(0xFFEF4444),
            title: 'Leave Group',
            titleColor: const Color(0xFFEF4444),
            onTap: _isLoading ? () {} : _handleLeaveGroup,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
    String? trailingText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? LiquidGlassTheme.textSecondary).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor ?? LiquidGlassTheme.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: titleColor ?? LiquidGlassTheme.textPrimary,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: LiquidGlassTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: LiquidGlassTheme.textSecondary.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}
