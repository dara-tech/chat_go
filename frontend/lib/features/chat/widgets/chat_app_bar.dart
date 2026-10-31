import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/websocket/chat_socket_service.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../../profile/screens/user_profile_screen.dart';

class ChatAppBar extends StatelessWidget {
  final UserModel currentUser;
  final UserModel? partnerUser;
  final ChatGroup? group;
  final String title;
  final bool isWsConnected;
  final bool canPop;
  final bool isPartnerTyping;
  final VoidCallback? onGroupInfoTap;

  const ChatAppBar({
    super.key,
    required this.currentUser,
    this.partnerUser,
    this.group,
    required this.title,
    required this.isWsConnected,
    required this.canPop,
    this.isPartnerTyping = false,
    this.onGroupInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final partner = partnerUser;
    final isDirectChat = partner != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgSurface,
        border: Border(
          bottom: BorderSide(
            color: LiquidGlassTheme.dividerHairline,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Optional Back Button
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 17,
                  color: LiquidGlassTheme.textPrimary,
                ),
              ),
            ),
          ],

          // Avatar and Title Info (Tappable to view full profile or group info)
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (group != null) {
                  onGroupInfoTap?.call();
                } else if (partner != null) {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: partner.id,
                        initialUser: partner,
                        currentUser: currentUser,
                        fromChatScreen: true,
                      ),
                    ),
                  );
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // Avatar with live presence badge
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      ChatSocketService.instance.connectionStateNotifier,
                      ChatSocketService.instance.onlineUserIdsNotifier,
                    ]),
                    builder: (context, _) {
                      final isPartnerOnline = partner != null &&
                          (ChatSocketService.instance.isUserOnline(partner.id) || partner.isOnline == true);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: group != null
                                  ? const LinearGradient(
                                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LiquidGlassTheme.primaryButtonGradient,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: group != null
                                ? (group!.avatarUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          ApiClient.resolveAvatarUrl(group!.avatarUrl),
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, error, stack) => Center(
                                            child: Text(
                                              group!.name.isNotEmpty ? group!.name[0].toUpperCase() : 'G',
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          CupertinoIcons.person_2_fill,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ))
                                : (partner != null && partner.avatarUrl.isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          ApiClient.resolveAvatarUrl(partner.avatarUrl),
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, error, stack) => Center(
                                            child: Text(
                                              partner.displayName.isNotEmpty
                                                  ? partner.displayName[0].toUpperCase()
                                                  : 'U',
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: partner != null
                                            ? Text(
                                                partner.displayName.isNotEmpty
                                                    ? partner.displayName[0].toUpperCase()
                                                    : 'U',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                CupertinoIcons.chat_bubble_2_fill,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                      ),
                          ),
                          if (isDirectChat && isPartnerOnline)
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
                                    color: LiquidGlassTheme.bgSurface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 12),

                  // Title & Subtitle Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: LiquidGlassTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isPartnerTyping) ...[
                          const _AppBarTypingIndicator(),
                        ] else ...[
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              ChatSocketService.instance.connectionStateNotifier,
                              ChatSocketService.instance.onlineUserIdsNotifier,
                            ]),
                            builder: (context, _) {
                              final connState = ChatSocketService.instance.connectionState;
                              final isPartnerOnline = partner != null &&
                                  (ChatSocketService.instance.isUserOnline(partner.id) || partner.isOnline == true);

                              Color dotColor = const Color(0xFF94A3B8);
                              String statusText = 'Offline';
                              Color textColor = LiquidGlassTheme.textMuted;

                              switch (connState) {
                                case SocketConnectionState.connecting:
                                  dotColor = const Color(0xFFF59E0B);
                                  statusText = 'Connecting...';
                                  textColor = const Color(0xFFF59E0B);
                                  break;
                                case SocketConnectionState.reconnecting:
                                  dotColor = const Color(0xFFF59E0B);
                                  statusText = 'Reconnecting...';
                                  textColor = const Color(0xFFF59E0B);
                                  break;
                                case SocketConnectionState.waitingForNetwork:
                                  dotColor = const Color(0xFFEF4444);
                                  statusText = 'Waiting for connection';
                                  textColor = const Color(0xFFEF4444);
                                  break;
                                case SocketConnectionState.disconnected:
                                  dotColor = const Color(0xFF94A3B8);
                                  statusText = 'Disconnected';
                                  textColor = LiquidGlassTheme.textMuted;
                                  break;
                                case SocketConnectionState.connected:
                                  if (group != null) {
                                    dotColor = LiquidGlassTheme.accentEmerald;
                                    statusText = '${group!.memberCount} members';
                                    textColor = LiquidGlassTheme.textMuted;
                                  } else if (isDirectChat) {
                                    if (isPartnerOnline) {
                                      dotColor = LiquidGlassTheme.accentEmerald;
                                      statusText = 'Online';
                                      textColor = LiquidGlassTheme.accentEmerald;
                                    } else {
                                      dotColor = const Color(0xFF94A3B8);
                                      statusText = 'Offline';
                                      textColor = LiquidGlassTheme.textMuted;
                                    }
                                  } else {
                                    dotColor = LiquidGlassTheme.accentEmerald;
                                    statusText = 'Live';
                                    textColor = LiquidGlassTheme.accentEmerald;
                                  }
                                  break;
                              }

                              return Row(
                                children: [
                                  Container(
                                    width: 6.5,
                                    height: 6.5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: dotColor,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    statusText,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (group != null) ...[
            GestureDetector(
              onTap: onGroupInfoTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.info,
                  size: 18,
                  color: LiquidGlassTheme.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppBarTypingIndicator extends StatefulWidget {
  const _AppBarTypingIndicator();

  @override
  State<_AppBarTypingIndicator> createState() => _AppBarTypingIndicatorState();
}

class _AppBarTypingIndicatorState extends State<_AppBarTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final val = ((_anim.value * 4).floor()) % 4;
        final dots = '.' * (val + 1);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.pencil_ellipsis_rectangle,
              size: 13,
              color: LiquidGlassTheme.accentBlue,
            ),
            const SizedBox(width: 4),
            Text(
              'typing$dots',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: LiquidGlassTheme.accentBlue,
              ),
            ),
          ],
        );
      },
    );
  }
}

