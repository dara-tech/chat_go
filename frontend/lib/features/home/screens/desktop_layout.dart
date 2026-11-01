import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../media/screens/media_viewer_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../settings/screens/chat_folders_settings_screen.dart';
import '../../../core/notifications/notification_alert_service.dart';
import '../../../core/services/media_download_service.dart';
import '../../../core/websocket/chat_socket_service.dart';
import '../widgets/desktop_nav_rail.dart';

/// Desktop layout breakpoint — screens wider than this use [DesktopLayout].
const double kDesktopBreakpoint = 720;

/// Desktop-specific shell that wraps the same feature screens used on mobile
/// but arranges them in a two-panel (sidebar + content) layout.
///
/// On small screens it degrades gracefully to a narrow single-panel view
/// (the rail collapses to icon-only). The ChatScreen, when opened, slides
/// into the right panel instead of pushing a new route.
class DesktopLayout extends StatefulWidget {
  final UserModel user;

  const DesktopLayout({super.key, required this.user});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout>
    with WidgetsBindingObserver {
  // ── State ────────────────────────────────────────────────────────────────
  int _selectedTab = 0;
  late UserModel _currentUser;

  /// The active chat (right panel). Null = show the "select a conversation"
  /// placeholder.
  ChatScreen? _activeChatScreen;

  /// Detail or settings screen shown in the right panel (e.g. Chat Folders)
  /// keeping the navigation rail and the chat list intact on the left.
  Widget? _activeDetailScreen;

  final GlobalKey<ChatListScreenState> _chatListKey =
      GlobalKey<ChatListScreenState>();

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;

    // Set up notification / media deep-link builders to open inside the
    // desktop right-panel rather than pushing a new route.
    NotificationAlertService.chatScreenBuilder = (curr, partner) => ChatScreen(
          currentUser: curr,
          chatUser: partner,
          title: partner.displayName,
        );

    MediaDownloadService.imageViewerBuilder = (url, fn) => MediaViewerScreen(
          items: [
            MediaViewerItem(
              id: fn,
              mediaUrl: url,
              senderName: fn,
              timestamp: DateTime.now(),
            ),
          ],
        );

    NotificationAlertService.instance.init(user: _currentUser);
    ChatSocketService.instance.connect();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!ChatSocketService.instance.isConnected) {
        ChatSocketService.instance.connect();
      }
      _chatListKey.currentState?.refresh();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _openChatWithUser(UserModel user) {
    setState(() {
      _activeDetailScreen = null;
      _activeChatScreen = ChatScreen(
        key: ValueKey('chat_user_${user.id}'),
        currentUser: _currentUser,
        title: user.displayName.isNotEmpty ? user.displayName : user.username,
        chatUser: user,
      );
      _selectedTab = 0; // keep Chats tab active in the rail
    });
    _chatListKey.currentState?.refresh();
  }

  void _openChatWithGroup(ChatGroup group) {
    setState(() {
      _activeDetailScreen = null;
      _activeChatScreen = ChatScreen(
        key: ValueKey('chat_group_${group.id}'),
        currentUser: _currentUser,
        title: group.name,
        group: group,
      );
      _selectedTab = 0;
    });
  }

  void _openChatFoldersSettings({
    List<UserModel> users = const [],
    List<ChatGroup> groups = const [],
  }) {
    setState(() {
      _activeDetailScreen = ChatFoldersSettingsScreen(
        availableUsers: users,
        availableGroups: groups,
        onClose: () {
          setState(() => _activeDetailScreen = null);
        },
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: ThemeController.instance.scaffoldBg,
          body: SafeArea(
            bottom: false,
            child: _DesktopShell(
              navRail: _buildNavRail(),
              leftPanel: _buildLeftPanel(),
              rightPanel: _buildRightPanel(),
              activeChatScreen: _activeChatScreen,
            ),
          ),
        );
      },
    );
  }

  // ── Nav rail ──────────────────────────────────────────────────────────────
  Widget _buildNavRail() {
    final effectiveIndex = _activeDetailScreen != null
        ? 2
        : (_selectedTab >= 2 ? _selectedTab + 1 : _selectedTab);

    return DesktopNavRail(
      currentIndex: effectiveIndex,
      onTabSelected: (i) => setState(() {
        if (i == 2) {
          // Open Chat Folders in right panel, keep chat list on the left
          _selectedTab = 0;
          _openChatFoldersSettings();
        } else {
          final tabIndex = i > 2 ? i - 1 : i;
          _selectedTab = tabIndex;
          _activeDetailScreen = null;
          if (tabIndex != 0) _activeChatScreen = null;
        }
      }),
      items: const [
        DesktopNavRailItem(
          icon: CupertinoIcons.chat_bubble_2,
          activeIcon: CupertinoIcons.chat_bubble_2_fill,
          label: 'Chats',
        ),
        DesktopNavRailItem(
          icon: CupertinoIcons.person_2,
          activeIcon: CupertinoIcons.person_2_fill,
          label: 'People',
        ),
        DesktopNavRailItem(
          icon: CupertinoIcons.folder,
          activeIcon: CupertinoIcons.folder_fill,
          label: 'Folders',
        ),
        DesktopNavRailItem(
          icon: CupertinoIcons.person_crop_circle,
          activeIcon: CupertinoIcons.person_crop_circle_fill,
          label: 'Profile',
        ),
      ],
      bottomAction: _buildBottomAction(),
    );
  }

  Widget _buildBottomAction() {
    final theme = ThemeController.instance;
    return Tooltip(
      message: theme.isDark ? 'Switch to Light' : 'Switch to Dark',
      child: GestureDetector(
        onTap: () => theme.toggleDarkMode(),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: LiquidGlassTheme.inputFill,
            shape: BoxShape.circle,
            border: Border.all(
              color: LiquidGlassTheme.borderSubtle,
              width: 0.8,
            ),
          ),
          child: Icon(
            theme.isDark
                ? CupertinoIcons.sun_max_fill
                : CupertinoIcons.moon_fill,
            size: 17,
            color: LiquidGlassTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Left panel: tab body ──────────────────────────────────────────────────
  Widget _buildLeftPanel() {
    switch (_selectedTab) {
      case 0:
        return ChatListScreen(
          key: _chatListKey,
          currentUser: _currentUser,
          onOpenChat: _openChatWithUser,
          onOpenGroupChat: _openChatWithGroup,
          onOpenChatFolders: _openChatFoldersSettings,
        );
      case 1:
        return ContactsScreen(
          currentUser: _currentUser,
          onSelectUser: _openChatWithUser,
        );
      case 2:
        return ProfileScreen(currentUser: _currentUser);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Right panel: active chat, detail screen, or placeholder ───────────────
  Widget _buildRightPanel() {
    if (_activeDetailScreen != null) {
      return _activeDetailScreen!;
    }
    if (_activeChatScreen != null) {
      return _activeChatScreen!;
    }
    return _DesktopEmptyChat();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop shell: rail + left panel (fixed width) + right panel (expanded)
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopShell extends StatelessWidget {
  final Widget navRail;
  final Widget leftPanel;
  final Widget rightPanel;
  final Widget? activeChatScreen;

  const _DesktopShell({
    required this.navRail,
    required this.leftPanel,
    required this.rightPanel,
    this.activeChatScreen,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Very narrow window: show only the active panel without the rail
    if (width < 500) {
      return activeChatScreen ?? leftPanel;
    }

    return Row(
      children: [
        // 1 ── Navigation rail
        navRail,

        // 2 ── Left panel (chat list / contacts / profile)
        SizedBox(
          width: _leftPanelWidth(width),
          child: leftPanel,
        ),

        // 3 ── Vertical divider
        _VerticalDivider(),

        // 4 ── Right panel (chat or placeholder)
        Expanded(child: rightPanel),
      ],
    );
  }

  double _leftPanelWidth(double totalWidth) {
    // Clamp between 280 and 360 px depending on available space
    if (totalWidth < 900) return 280;
    if (totalWidth < 1200) return 320;
    return 360;
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.8,
      color: LiquidGlassTheme.dividerHairline,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty right-panel placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopEmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeController.instance.primaryColor;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Frosted glass icon container
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: LiquidGlassTheme.bgCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: LiquidGlassTheme.borderSubtle,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.08),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              CupertinoIcons.chat_bubble_2,
              color: LiquidGlassTheme.textMuted,
              size: 34,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Select a conversation',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: LiquidGlassTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Choose a chat from the list on the left\nor start a new one.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: LiquidGlassTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
