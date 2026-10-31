import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/user_model.dart';

class ChatTypingBubble extends StatefulWidget {
  final UserModel? partnerUser;

  const ChatTypingBubble({
    super.key,
    this.partnerUser,
  });

  @override
  State<ChatTypingBubble> createState() => _ChatTypingBubbleState();
}

class _ChatTypingBubbleState extends State<ChatTypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final partner = widget.partnerUser;
    final senderName = partner?.displayName ?? 'Partner';
    final avatarUrl = partner?.avatarUrl ?? '';
    final resolvedAvatar = avatarUrl.isNotEmpty ? ApiClient.resolveAvatarUrl(avatarUrl) : '';
    final bubbleColor = LiquidGlassTheme.bgCard;
    final borderColor = LiquidGlassTheme.borderSubtle;
    final accent = theme.current;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (theme.showAvatarInChat) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                color: LiquidGlassTheme.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 1),
              ),
              child: resolvedAvatar.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        resolvedAvatar,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Center(
                          child: Text(
                            senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent.primary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent.primary,
                        ),
                      ),
                    ),
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: borderColor, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBouncingDot(0, accent.primary),
                const SizedBox(width: 4),
                _buildBouncingDot(1, accent.primary),
                const SizedBox(width: 4),
                _buildBouncingDot(2, accent.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBouncingDot(int index, Color color) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final double progress = (_animController.value - (index * 0.2)) % 1.0;
        final double offset = (progress >= 0 && progress <= 0.5)
            ? -4.0 * (1.0 - (progress - 0.25).abs() * 4.0)
            : 0.0;
        final double opacity = (progress >= 0 && progress <= 0.5) ? 1.0 : 0.45;

        return Transform.translate(
          offset: Offset(0, offset.clamp(-4.0, 0.0)),
          child: Opacity(
            opacity: opacity.clamp(0.35, 1.0),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
