import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeColor {
  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color lightBg;

  const AppThemeColor({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.lightBg,
  });
}

class AppBackgroundPreset {
  final String id;
  final String name;
  final String subtitle;
  final Color scaffoldBg;
  final Color surfaceBg;
  final Color cardBg;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color inputFill;
  final bool isDark;

  const AppBackgroundPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.scaffoldBg,
    required this.surfaceBg,
    required this.cardBg,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.inputFill,
    required this.isDark,
  });
}

class AppBubbleStyle {
  final String id;
  final String name;
  final String subtitle;
  final double radius;
  final double tailRadius;
  final bool hasCurvedTail;

  const AppBubbleStyle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.radius,
    required this.tailRadius,
    this.hasCurvedTail = false,
  });

  BorderRadius getBorderRadius(bool isMe) {
    if (radius == tailRadius) {
      return BorderRadius.circular(radius);
    }
    return BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(isMe ? radius : tailRadius),
      bottomRight: Radius.circular(isMe ? tailRadius : radius),
    );
  }
}

class AppNavBarStyle {
  final String id;
  final String name;
  final String subtitle;

  const AppNavBarStyle({
    required this.id,
    required this.name,
    required this.subtitle,
  });
}

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const String _accentPrefKey = 'selected_theme_accent';
  static const String _bgPrefKey = 'selected_theme_bg';
  static const String _bubblePrefKey = 'selected_bubble_style';
  static const String _navBarPrefKey = 'selected_nav_bar_style';
  static const String _showAvatarPrefKey = 'show_avatar_in_chat';

  static const List<AppNavBarStyle> navBarStyles = [
    AppNavBarStyle(
      id: 'clay_pill',
      name: 'Clay Pill',
      subtitle: 'Soft tinted container pill highlight',
    ),
    AppNavBarStyle(
      id: 'floating_dock',
      name: 'Floating Island',
      subtitle: 'Detached capsule dock with drop shadow',
    ),
    AppNavBarStyle(
      id: 'minimal_dot',
      name: 'Minimal Indicator',
      subtitle: 'Clean dock with glowing active dot',
    ),
    AppNavBarStyle(
      id: 'glass_glow',
      name: 'Top Accent Line',
      subtitle: 'Translucent bar with glowing top indicator',
    ),
    AppNavBarStyle(
      id: 'filled_capsule',
      name: 'Solid Accent Capsule',
      subtitle: 'Vibrant filled gradient capsule with white text',
    ),
  ];

  static const List<AppBubbleStyle> bubbleStyles = [
    AppBubbleStyle(
      id: 'telegram',
      name: 'Telegram Tail',
      subtitle: 'Curved tail with inline status',
      radius: 18.0,
      tailRadius: 2.0,
      hasCurvedTail: true,
    ),
    AppBubbleStyle(
      id: 'tiktok',
      name: 'TikTok DM',
      subtitle: 'Dynamic anchor tail',
      radius: 18.0,
      tailRadius: 4.0,
    ),
    AppBubbleStyle(
      id: 'capsule',
      name: 'Soft Capsule',
      subtitle: 'Ultra-smooth pill',
      radius: 22.0,
      tailRadius: 22.0,
    ),
    AppBubbleStyle(
      id: 'classic',
      name: 'Classic Chat',
      subtitle: 'Subtle taper corner',
      radius: 15.0,
      tailRadius: 3.0,
    ),
    AppBubbleStyle(
      id: 'sleek',
      name: 'Clean Slate',
      subtitle: 'Modern squircle',
      radius: 10.0,
      tailRadius: 10.0,
    ),
  ];

  static const List<AppThemeColor> presets = [
    AppThemeColor(
      id: 'blue',
      name: 'Royal Blue',
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF1D4ED8),
      lightBg: Color(0xFFEFF6FF),
    ),
    AppThemeColor(
      id: 'purple',
      name: 'Electric Purple',
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFF6D28D9),
      lightBg: Color(0xFFF5F3FF),
    ),
    AppThemeColor(
      id: 'emerald',
      name: 'Emerald Mint',
      primary: Color(0xFF059669),
      secondary: Color(0xFF047857),
      lightBg: Color(0xFFECFDF5),
    ),
    AppThemeColor(
      id: 'orange',
      name: 'Sunset Orange',
      primary: Color(0xFFEA580C),
      secondary: Color(0xFFC2410C),
      lightBg: Color(0xFFFFF7ED),
    ),
    AppThemeColor(
      id: 'rose',
      name: 'Neon Rose',
      primary: Color(0xFFE11D48),
      secondary: Color(0xFFBE123C),
      lightBg: Color(0xFFFFF1F2),
    ),
    AppThemeColor(
      id: 'slate',
      name: 'Midnight Slate',
      primary: Color(0xFF0F172A),
      secondary: Color(0xFF334155),
      lightBg: Color(0xFFF8FAFC),
    ),
  ];

  static const List<AppBackgroundPreset> bgPresets = [
    AppBackgroundPreset(
      id: 'white',
      name: 'Pure White',
      subtitle: 'Clean & Bright',
      scaffoldBg: Color(0xFFFFFFFF),
      surfaceBg: Color(0xFFFFFFFF),
      cardBg: Color(0xFFF8FAFC),
      border: Color(0xFFE2E8F0),
      divider: Color(0xFFF1F5F9),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF64748B),
      textMuted: Color(0xFF94A3B8),
      inputFill: Color(0xFFF1F5F9),
      isDark: false,
    ),
    AppBackgroundPreset(
      id: 'clay',
      name: 'Clay Dim',
      subtitle: 'Soft Ceramic',
      scaffoldBg: Color(0xFFF1F5F9),
      surfaceBg: Color(0xFFF1F5F9),
      cardBg: Color(0xFFFFFFFF),
      border: Color(0xFFE2E8F0),
      divider: Color(0xFFE2E8F0),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF64748B),
      textMuted: Color(0xFF94A3B8),
      inputFill: Color(0xFFE2E8F0),
      isDark: false,
    ),
    AppBackgroundPreset(
      id: 'cream',
      name: 'Warm Cream',
      subtitle: 'Paper & Linen',
      scaffoldBg: Color(0xFFFAF7F2),
      surfaceBg: Color(0xFFFAF7F2),
      cardBg: Color(0xFFFFFFFF),
      border: Color(0xFFE8E2D8),
      divider: Color(0xFFEFE9DE),
      textPrimary: Color(0xFF1C1917),
      textSecondary: Color(0xFF78716C),
      textMuted: Color(0xFFA8A29E),
      inputFill: Color(0xFFF0EBE1),
      isDark: false,
    ),
    AppBackgroundPreset(
      id: 'dark',
      name: 'Dark Slate',
      subtitle: 'Modern Charcoal',
      scaffoldBg: Color(0xFF0F172A),
      surfaceBg: Color(0xFF0F172A),
      cardBg: Color(0xFF1E293B),
      border: Color(0xFF334155),
      divider: Color(0xFF1E293B),
      textPrimary: Color(0xFFF8FAFC),
      textSecondary: Color(0xFF94A3B8),
      textMuted: Color(0xFF64748B),
      inputFill: Color(0xFF1E293B),
      isDark: true,
    ),
    AppBackgroundPreset(
      id: 'black',
      name: 'OLED Black',
      subtitle: 'Pitch Dark',
      scaffoldBg: Color(0xFF000000),
      surfaceBg: Color(0xFF000000),
      cardBg: Color(0xFF121215),
      border: Color(0xFF26262B),
      divider: Color(0xFF1C1C21),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFA1A1AA),
      textMuted: Color(0xFF71717A),
      inputFill: Color(0xFF1A1A1E),
      isDark: true,
    ),
  ];

  AppThemeColor _current = presets[0];
  AppBackgroundPreset _currentBg = bgPresets[0];
  AppBubbleStyle _currentBubble = bubbleStyles[0];
  AppNavBarStyle _currentNavBarStyle = navBarStyles[0];
  bool _showAvatarInChat = true;

  AppThemeColor get current => _current;
  AppBackgroundPreset get bgPreset => _currentBg;
  AppBubbleStyle get bubbleStyle => _currentBubble;
  AppNavBarStyle get navBarStyle => _currentNavBarStyle;
  bool get showAvatarInChat => _showAvatarInChat;

  BorderRadius getBubbleRadius(bool isMe) => _currentBubble.getBorderRadius(isMe);

  Color get primaryColor {
    if (_current.id == 'slate') {
      return _currentBg.isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    }
    return _current.primary;
  }

  Color get secondaryColor {
    if (_current.id == 'slate') {
      return _currentBg.isDark ? const Color(0xFF64748B) : const Color(0xFF1E293B);
    }
    return _current.secondary;
  }

  Color get lightBgColor {
    if (_current.id == 'slate') {
      return _currentBg.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    }
    return _current.lightBg;
  }

  Color get scaffoldBg => _currentBg.scaffoldBg;
  Color get surfaceBg => _currentBg.surfaceBg;
  Color get cardBg => _currentBg.cardBg;
  Color get border => _currentBg.border;
  Color get divider => _currentBg.divider;
  Color get textPrimary => _currentBg.textPrimary;
  Color get textSecondary => _currentBg.textSecondary;
  Color get textMuted => _currentBg.textMuted;
  Color get inputFill => _currentBg.inputFill;
  bool get isDark => _currentBg.isDark;

  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, secondaryColor],
      );

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAccentId = prefs.getString(_accentPrefKey);
      if (savedAccentId != null) {
        _current = presets.firstWhere(
          (p) => p.id == savedAccentId,
          orElse: () => presets[0],
        );
      }
      final savedBgId = prefs.getString(_bgPrefKey);
      if (savedBgId != null) {
        _currentBg = bgPresets.firstWhere(
          (p) => p.id == savedBgId,
          orElse: () => bgPresets[0],
        );
      }
      final savedBubbleId = prefs.getString(_bubblePrefKey);
      if (savedBubbleId != null) {
        _currentBubble = bubbleStyles.firstWhere(
          (b) => b.id == savedBubbleId,
          orElse: () => bubbleStyles[0],
        );
      }
      final savedNavBarId = prefs.getString(_navBarPrefKey);
      if (savedNavBarId != null) {
        _currentNavBarStyle = navBarStyles.firstWhere(
          (n) => n.id == savedNavBarId,
          orElse: () => navBarStyles[0],
        );
      }
      final savedShowAvatar = prefs.getBool(_showAvatarPrefKey);
      if (savedShowAvatar != null) {
        _showAvatarInChat = savedShowAvatar;
      }
      _syncSystemUi();
      notifyListeners();
    } catch (_) {
      // Graceful fallback for test environments
    }
  }

  void _syncSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _currentBg.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: _currentBg.scaffoldBg,
        systemNavigationBarIconBrightness: _currentBg.isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Future<void> setTheme(AppThemeColor theme) async {
    if (_current.id == theme.id) return;
    _current = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accentPrefKey, theme.id);
    } catch (_) {}
  }

  Future<void> setThemeById(String id) async {
    final theme = presets.firstWhere((p) => p.id == id, orElse: () => presets[0]);
    await setTheme(theme);
  }

  Future<void> setBgPreset(AppBackgroundPreset bg) async {
    if (_currentBg.id == bg.id) return;
    _currentBg = bg;
    _syncSystemUi();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bgPrefKey, bg.id);
    } catch (_) {}
  }

  Future<void> setBgPresetById(String id) async {
    final bg = bgPresets.firstWhere((p) => p.id == id, orElse: () => bgPresets[0]);
    await setBgPreset(bg);
  }

  Future<void> toggleDarkMode() async {
    if (isDark) {
      await setBgPresetById('clay');
    } else {
      await setBgPresetById('dark');
    }
  }

  Future<void> setBubbleStyle(AppBubbleStyle style) async {
    if (_currentBubble.id == style.id) return;
    _currentBubble = style;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bubblePrefKey, style.id);
    } catch (_) {}
  }

  Future<void> setBubbleStyleById(String id) async {
    final style = bubbleStyles.firstWhere((b) => b.id == id, orElse: () => bubbleStyles[0]);
    await setBubbleStyle(style);
  }

  Future<void> setNavBarStyle(AppNavBarStyle style) async {
    if (_currentNavBarStyle.id == style.id) return;
    _currentNavBarStyle = style;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_navBarPrefKey, style.id);
    } catch (_) {}
  }

  Future<void> setNavBarStyleById(String id) async {
    final style = navBarStyles.firstWhere((n) => n.id == id, orElse: () => navBarStyles[0]);
    await setNavBarStyle(style);
  }

  Future<void> setShowAvatarInChat(bool show) async {
    if (_showAvatarInChat == show) return;
    _showAvatarInChat = show;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showAvatarPrefKey, show);
    } catch (_) {}
  }
}
