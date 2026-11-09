import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/liquid_glass_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/widgets/chat_bubble_painter.dart';

class ThemeSettingsScreen extends StatelessWidget {
  final VoidCallback? onClose;

  const ThemeSettingsScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final currentTheme = ThemeController.instance.current;
        final currentBg = ThemeController.instance.bgPreset;
        final currentBubble = ThemeController.instance.bubbleStyle;
        final currentNavBar = ThemeController.instance.navBarStyle;
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          backgroundColor: ThemeController.instance.scaffoldBg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Header Bar
                _buildHeader(context),

                // Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      bottomInset > 0 ? bottomInset + 40 : 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live Interactive Preview Card
                        _buildLivePreviewCard(context, currentTheme, currentBg, currentBubble, currentNavBar),
                        const SizedBox(height: 24),

                        // Section 1: Accent Colors
                        _buildSectionLabel('ACCENT COLOR'),
                        _buildAccentColorCard(context, currentTheme),
                        const SizedBox(height: 24),

                        // Section 2: Background Themes
                        _buildSectionLabel('BACKGROUND STYLE'),
                        _buildBackgroundCard(context, currentBg),
                        const SizedBox(height: 24),

                        // Section 3: Bubble Format
                        _buildSectionLabel('CHAT BUBBLE FORMAT'),
                        _buildBubbleFormatCard(context, currentBubble),
                        const SizedBox(height: 24),

                        // Section 4: Navigation Bar Style
                        _buildSectionLabel('NAVIGATION BAR STYLE'),
                        _buildNavBarStyleCard(context, currentNavBar),
                        const SizedBox(height: 24),

                        // Section 5: Chat Preferences
                        _buildSectionLabel('CHAT BUBBLE OPTIONS'),
                        _buildChatPreferencesCard(context),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgScaffold,
        border: Border(
          bottom: BorderSide(
            color: LiquidGlassTheme.borderSubtle,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (onClose != null) {
                onClose!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Theme & Appearance',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlassTheme.textPrimary,
                  ),
                ),
                Text(
                  'Customize your look & feel',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ThemeController.instance.setThemeById('blue');
              ThemeController.instance.setBgPresetById('clay');
              ThemeController.instance.setBubbleStyleById('telegram');
              ThemeController.instance.setNavBarStyleById('clay_pill');
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LiquidGlassTheme.inputFill,
                shape: BoxShape.circle,
                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
              ),
              child: Icon(
                CupertinoIcons.arrow_counterclockwise,
                size: 18,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: LiquidGlassTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(
    BuildContext context,
    AppThemeColor theme,
    AppBackgroundPreset bg,
    AppBubbleStyle bubble,
    AppNavBarStyle navBar,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: ThemeController.instance.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'D',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Preview',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: LiquidGlassTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ThemeController.instance.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ThemeController.instance.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini Message Mockup
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LiquidGlassTheme.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
            ),
            child: Column(
              children: [
                // Incoming bubble
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (ThemeController.instance.showAvatarInChat) ...[
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 6, bottom: 2),
                        decoration: BoxDecoration(
                          color: LiquidGlassTheme.bgCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
                        ),
                        child: Center(
                          child: Text(
                            'D',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ThemeController.instance.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                    Flexible(
                      child: bubble.hasCurvedTail
                          ? CustomPaint(
                              painter: TelegramBubblePainter(
                                color: LiquidGlassTheme.bgCard,
                                borderColor: LiquidGlassTheme.borderSubtle,
                                borderWidth: 0.8,
                                isMe: false,
                                radius: bubble.radius,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12 + 7, 7, 12, 7),
                                child: _buildPreviewBubbleContent(
                                  'How do you like this format? ✨',
                                  '10:42 AM',
                                  false,
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: LiquidGlassTheme.bgCard,
                                borderRadius: bubble.getBorderRadius(false),
                                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
                              ),
                              child: _buildPreviewBubbleContent(
                                'How do you like this format? ✨',
                                '10:42 AM',
                                false,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Outgoing bubble
                Align(
                  alignment: Alignment.centerRight,
                  child: bubble.hasCurvedTail
                      ? CustomPaint(
                          painter: TelegramBubblePainter(
                            color: ThemeController.instance.primaryColor,
                            isMe: true,
                            radius: bubble.radius,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 7, 12 + 7, 7),
                            child: _buildPreviewBubbleContent(
                              'Noted',
                              '11:39 in the morning',
                              true,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: ThemeController.instance.primaryColor,
                            borderRadius: bubble.getBorderRadius(true),
                          ),
                          child: _buildPreviewBubbleContent(
                            'Noted',
                            '11:39 in the morning',
                            true,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Mini Navigation Bar Preview
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ThemeController.instance.isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: LiquidGlassTheme.borderSubtle,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniTab('Chats', CupertinoIcons.chat_bubble_2, false, navBar.id),
                _buildMiniTab('People', CupertinoIcons.person_2, false, navBar.id),
                _buildMiniTab('Profile', CupertinoIcons.person_crop_circle_fill, true, navBar.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTab(String label, IconData icon, bool isSelected, String styleId) {
    final primary = ThemeController.instance.primaryColor;
    final isDark = ThemeController.instance.isDark;

    Widget child;
    switch (styleId) {
      case 'floating_dock':
      case 'clay_pill':
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? primary.withOpacity(isDark ? 0.22 : 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isSelected ? primary : LiquidGlassTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? primary : LiquidGlassTheme.textMuted,
                ),
              ),
            ],
          ),
        );
        break;

      case 'filled_capsule':
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : LiquidGlassTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : LiquidGlassTheme.textMuted,
                ),
              ),
            ],
          ),
        );
        break;

      case 'minimal_dot':
        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? primary : LiquidGlassTheme.textMuted),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primary : LiquidGlassTheme.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: isSelected ? 3.5 : 0,
              height: isSelected ? 3.5 : 0,
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
        break;

      case 'glass_glow':
      default:
        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isSelected ? 16 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 2),
            Icon(icon, size: 13, color: isSelected ? primary : LiquidGlassTheme.textMuted),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primary : LiquidGlassTheme.textMuted,
              ),
            ),
          ],
        );
        break;
    }

    return child;
  }

  Widget _buildPreviewBubbleContent(String text, String time, bool isMe) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      runSpacing: 2,
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isMe ? FontWeight.w500 : FontWeight.w400,
            color: isMe ? Colors.white : LiquidGlassTheme.textPrimary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                time,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isMe ? Colors.white.withOpacity(0.85) : LiquidGlassTheme.textMuted,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.done_all,
                  size: 13,
                  color: Colors.white.withOpacity(0.90),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccentColorCard(BuildContext context, AppThemeColor currentTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Accent',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: LiquidGlassTheme.textPrimary,
                ),
              ),
              Text(
                currentTheme.name,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ThemeController.instance.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6 Swatches
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ThemeController.presets.map((preset) {
              final isSelected = currentTheme.id == preset.id;
              final isSlateDark = preset.id == 'slate' && ThemeController.instance.isDark;

              return GestureDetector(
                onTap: () {
                  ThemeController.instance.setTheme(preset);
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSlateDark
                              ? const [Color(0xFF94A3B8), Color(0xFF64748B)]
                              : [preset.primary, preset.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? (ThemeController.instance.isDark ? Colors.white : const Color(0xFF0F172A))
                              : (ThemeController.instance.isDark ? const Color(0xFF334155) : Colors.transparent),
                          width: 2.5,
                        ),
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(
                                CupertinoIcons.checkmark_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.name.split(' ').last,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? ThemeController.instance.primaryColor
                            : LiquidGlassTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundCard(BuildContext context, AppBackgroundPreset currentBg) {
    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle),
      ),
      child: Column(
        children: ThemeController.bgPresets.map((bg) {
          final isSelected = currentBg.id == bg.id;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ThemeController.instance.setBgPreset(bg);
              },
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Preview Swatch
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bg.scaffoldBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? ThemeController.instance.primaryColor
                              : (bg.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          width: isSelected ? 2.2 : 1.0,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Icon(
                                CupertinoIcons.checkmark_alt,
                                color: bg.isDark ? Colors.white : ThemeController.instance.primaryColor,
                                size: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),

                    // Title & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bg.name,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: LiquidGlassTheme.textPrimary,
                            ),
                          ),
                          Text(
                            bg.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: LiquidGlassTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active Radio Indicator
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? ThemeController.instance.primaryColor
                              : LiquidGlassTheme.textMuted,
                          width: isSelected ? 6 : 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBubbleFormatCard(BuildContext context, AppBubbleStyle currentBubble) {
    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle),
      ),
      child: Column(
        children: ThemeController.bubbleStyles.map((bubble) {
          final isSelected = currentBubble.id == bubble.id;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ThemeController.instance.setBubbleStyle(bubble);
              },
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Bubble Preview Swatch
                    bubble.hasCurvedTail
                        ? CustomPaint(
                            painter: TelegramBubblePainter(
                              color: isSelected
                                  ? ThemeController.instance.primaryColor
                                  : LiquidGlassTheme.inputFill,
                              borderColor: isSelected
                                  ? ThemeController.instance.primaryColor
                                  : LiquidGlassTheme.borderSubtle,
                              borderWidth: 1.0,
                              isMe: true,
                              radius: bubble.radius,
                              tailWidth: 5.0,
                            ),
                            child: SizedBox(
                              width: 44,
                              height: 32,
                              child: Center(
                                child: Text(
                                  'Chat',
                                  style: GoogleFonts.inter(
                                    color: isSelected ? Colors.white : LiquidGlassTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ThemeController.instance.primaryColor
                                  : LiquidGlassTheme.inputFill,
                              borderRadius: bubble.getBorderRadius(true),
                              border: Border.all(
                                color: isSelected
                                    ? ThemeController.instance.primaryColor
                                    : LiquidGlassTheme.borderSubtle,
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Chat',
                                style: GoogleFonts.inter(
                                  color: isSelected ? Colors.white : LiquidGlassTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(width: 14),

                    // Title & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                bubble.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: LiquidGlassTheme.textPrimary,
                                ),
                              ),
                              if (bubble.id == 'telegram') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: ThemeController.instance.primaryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'FEATURED',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: ThemeController.instance.primaryColor,
                                    ),
                                  ),
                                ),
                              ] else if (bubble.id == 'tiktok') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: ThemeController.instance.primaryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'POPULAR',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: ThemeController.instance.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            bubble.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: LiquidGlassTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active Radio Indicator
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? ThemeController.instance.primaryColor
                              : LiquidGlassTheme.textMuted,
                          width: isSelected ? 6 : 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatPreferencesCard(BuildContext context) {
    final showAvatar = ThemeController.instance.showAvatarInChat;

    return Container(
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LiquidGlassTheme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ThemeController.instance.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(CupertinoIcons.person_crop_circle, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Profile Avatars on Bubbles',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: LiquidGlassTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Show sender profile bubble next to messages',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: LiquidGlassTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: showAvatar,
              activeColor: ThemeController.instance.primaryColor,
              onChanged: (val) {
                ThemeController.instance.setShowAvatarInChat(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarStyleCard(BuildContext context, AppNavBarStyle currentNavBar) {
    final primary = ThemeController.instance.primaryColor;
    final isDark = ThemeController.instance.isDark;

    const styles = [
      {'id': 'clay_pill', 'label': 'Pill'},
      {'id': 'floating_dock', 'label': 'Island'},
      {'id': 'minimal_dot', 'label': 'Dot'},
      {'id': 'glass_glow', 'label': 'Line'},
      {'id': 'filled_capsule', 'label': 'Capsule'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: styles.map((item) {
          final styleId = item['id']!;
          final label = item['label']!;
          final isSelected = currentNavBar.id == styleId;
          final styleObj = ThemeController.navBarStyles.firstWhere(
            (s) => s.id == styleId,
            orElse: () => ThemeController.navBarStyles[0],
          );

          return Expanded(
            child: GestureDetector(
              onTap: () {
                ThemeController.instance.setNavBarStyle(styleObj);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withOpacity(isDark ? 0.20 : 0.12)
                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavBarMiniPreview(styleId, isSelected, primary),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? primary : LiquidGlassTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavBarMiniPreview(String styleId, bool isSelected, Color primary) {
    final isDark = ThemeController.instance.isDark;
    final bg = isDark ? const Color(0xFF16181F) : const Color(0xFFF1F5F9);
    final borderCol = isSelected ? primary.withOpacity(0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    Widget content;
    switch (styleId) {
      case 'floating_dock':
        content = Center(
          child: Container(
            width: 36,
            height: 18,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderCol, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(CupertinoIcons.chat_bubble_2, size: 8, color: LiquidGlassTheme.textMuted),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(CupertinoIcons.person_crop_circle_fill, size: 8, color: primary),
                ),
              ],
            ),
          ),
        );
        break;

      case 'minimal_dot':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(CupertinoIcons.chat_bubble_2, size: 9, color: LiquidGlassTheme.textMuted),
                Icon(CupertinoIcons.person_crop_circle_fill, size: 9, color: primary),
              ],
            ),
            const SizedBox(height: 1.5),
            Align(
              alignment: const Alignment(0.45, 0),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
        break;

      case 'glass_glow':
        content = Column(
          children: [
            Align(
              alignment: const Alignment(0.45, 0),
              child: Container(
                width: 12,
                height: 1.5,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(CupertinoIcons.chat_bubble_2, size: 9, color: LiquidGlassTheme.textMuted),
                  Icon(CupertinoIcons.person_crop_circle_fill, size: 9, color: primary),
                ],
              ),
            ),
          ],
        );
        break;

      case 'filled_capsule':
        content = Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(CupertinoIcons.chat_bubble_2, size: 9, color: LiquidGlassTheme.textMuted),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(CupertinoIcons.person_crop_circle_fill, size: 8, color: Colors.white),
              ),
            ],
          ),
        );
        break;

      case 'clay_pill':
      default:
        content = Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(CupertinoIcons.chat_bubble_2, size: 9, color: LiquidGlassTheme.textMuted),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(CupertinoIcons.person_crop_circle_fill, size: 8, color: primary),
              ),
            ],
          ),
        );
        break;
    }

    return Container(
      width: 44,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 0.8,
        ),
      ),
      child: content,
    );
  }
}
