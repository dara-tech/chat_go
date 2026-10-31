import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_controller.dart';
import '../expression_models.dart';
import '../expression_registry.dart';
import 'animated_emoji_widget.dart';
import 'animated_sticker_widget.dart';
import 'fluent_emoji_widget.dart';
import 'interactive_reaction_widget.dart';

/// Full-featured Telegram / iOS style Expression Keyboard Sheet
/// Supports:
/// 1. Animated Emoji (Lottie JSON)
/// 2. Animated Stickers (WebP)
/// 3. Interactive Reactions (Rive)
/// 4. Normal Emoji (Unicode / Fluent 3D Emoji)
class ExpressionPickerSheet extends StatefulWidget {
  final Function(String emojiText)? onSelectEmoji;
  final Function(AnimatedEmojiItem animatedEmoji)? onSelectAnimatedEmoji;
  final Function(AnimatedStickerItem sticker)? onSelectSticker;
  final Function(InteractiveReactionItem reaction)? onSelectReaction;

  const ExpressionPickerSheet({
    super.key,
    this.onSelectEmoji,
    this.onSelectAnimatedEmoji,
    this.onSelectSticker,
    this.onSelectReaction,
  });

  static Future<void> show(
    BuildContext context, {
    Function(String emojiText)? onSelectEmoji,
    Function(AnimatedEmojiItem animatedEmoji)? onSelectAnimatedEmoji,
    Function(AnimatedStickerItem sticker)? onSelectSticker,
    Function(InteractiveReactionItem reaction)? onSelectReaction,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpressionPickerSheet(
        onSelectEmoji: onSelectEmoji,
        onSelectAnimatedEmoji: onSelectAnimatedEmoji,
        onSelectSticker: onSelectSticker,
        onSelectReaction: onSelectReaction,
      ),
    );
  }

  @override
  State<ExpressionPickerSheet> createState() => _ExpressionPickerSheetState();
}

class _ExpressionPickerSheetState extends State<ExpressionPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final isDark = theme.isDark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.58,
      decoration: BoxDecoration(
        color: theme.cardBg.withOpacity(isDark ? 0.94 : 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.12) : theme.border,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.40 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Top Grabber Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: theme.textMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // 2. Segmented Mode Switcher (Emoji • Stickers • Reactions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : theme.inputFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.06) : theme.border.withOpacity(0.6),
                  width: 0.6,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.cardBg,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: theme.textPrimary,
                unselectedLabelColor: theme.textSecondary,
                labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: '😀 Emojis'),
                  Tab(text: '🐱 Stickers'),
                  Tab(text: '✨ Reactions'),
                ],
              ),
            ),
          ),

          // 3. Tab Views Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmojisTab(theme),
                _buildStickersTab(theme),
                _buildReactionsTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: EMOJIS (Animated Lottie + Fluent 3D)
  // ==========================================
  Widget _buildEmojisTab(ThemeController theme) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Section: Animated Emojis
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Animated Emojis',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final emoji = ExpressionRegistry.animatedEmojis[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSelectAnimatedEmoji?.call(emoji);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: AnimatedEmojiWidget(
                        emoji: emoji,
                        size: 34,
                      ),
                    ),
                  ),
                );
              },
              childCount: ExpressionRegistry.animatedEmojis.length,
            ),
          ),
        ),

        // Section: Standard Emojis
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Standard Emojis',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final emoji = ExpressionRegistry.fluentEmojis[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelectEmoji?.call(emoji.unicode);
                    Navigator.of(context).pop();
                  },
                  child: Center(
                    child: FluentEmojiWidget(
                      emoji: emoji,
                      size: 28,
                    ),
                  ),
                );
              },
              childCount: ExpressionRegistry.fluentEmojis.length,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: STICKERS
  // ==========================================
  Widget _buildStickersTab(ThemeController theme) {
    final stickers = ExpressionRegistry.animatedStickers;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Animated Stickers',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final sticker = stickers[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onSelectSticker?.call(sticker);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.border.withOpacity(0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: AnimatedStickerWidget(
                        sticker: sticker,
                        size: 96,
                      ),
                    ),
                  ),
                );
              },
              childCount: stickers.length,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: REACTIONS
  // ==========================================
  Widget _buildReactionsTab(ThemeController theme) {
    final reactions = ExpressionRegistry.interactiveReactions;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Interactive Reactions',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final reaction = reactions[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSelectReaction?.call(reaction);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.border.withOpacity(0.5),
                        width: 0.6,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: InteractiveReactionWidget(
                              reaction: reaction,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          reaction.name,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: theme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: reactions.length,
            ),
          ),
        ),
      ],
    );
  }
}
