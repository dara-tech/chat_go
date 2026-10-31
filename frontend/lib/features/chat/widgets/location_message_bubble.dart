import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/user_model.dart';
import '../../../widgets/cartodb_map_view.dart';
import '../../map/domain/map_location.dart';

class LocationMessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final UserModel currentUser;
  final UserModel? partnerUser;
  final VoidCallback onTap;

  const LocationMessageBubble({
    super.key,
    required this.msg,
    required this.currentUser,
    this.partnerUser,
    required this.onTap,
  });

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final a = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $a';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final accent = theme.current;
    final bgPreset = theme.bgPreset;

    final content = (msg['content'] as String?) ?? '';
    final loc = MapLocation.parseContent(content);

    final isMe = (msg['sender_id'] == currentUser.id) || (msg['is_me'] == true);
    final isRead = msg['is_read'] == true;
    final forwardFrom = (msg['forward_from'] as String?)?.trim() ?? '';
    final sender = (msg['username'] as String?) ?? '';
    final avatarUrl = isMe
        ? currentUser.avatarUrl
        : ((msg['sender_avatar'] as String?)?.trim() ?? partnerUser?.avatarUrl ?? '');
    final markerUsername = isMe ? currentUser.username : sender;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.72,
        height: 180,
        decoration: BoxDecoration(
          color: bgPreset.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. CartoDB Map Preview
              CartoDbMapView(
                latitude: loc.latitude,
                longitude: loc.longitude,
                zoom: 15,
                mapStyle: bgPreset.isDark ? CartoMapStyle.dark : CartoMapStyle.voyager,
                showLabels: false,
              ),

              // 2. Center User / Place Pin
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 32,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: accent.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.2),
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: ClipOval(
                        child: avatarUrl.isNotEmpty
                            ? Image.network(
                                ApiClient.resolveAvatarUrl(avatarUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => _buildFallback(markerUsername, accent),
                              )
                            : _buildFallback(markerUsername, accent),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Forwarded header tag
              if (forwardFrom.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.60),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.arrowshape_turn_up_right_fill,
                          size: 10,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Forwarded from $forwardFrom',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Place display name tag & timestamp / status in a responsive bottom row
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (loc.displayName.isNotEmpty)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.location_solid,
                                size: 11,
                                color: Color(0xFF007AFF),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  loc.displayName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(msg['timestamp']),
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 3),
                            Icon(
                              isRead ? Icons.done_all : Icons.done,
                              size: 13,
                              color: isRead ? const Color(0xFF67E8F9) : Colors.white.withOpacity(0.80),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(String name, dynamic accent) {
    return Container(
      color: accent.primary,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
