import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/notifications/notification_alert_service.dart';
import '../../../core/services/chat_folder_controller.dart';
import '../../../core/services/media_download_service.dart';
import '../../../core/storage/local_chat_storage.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/websocket/chat_socket_service.dart';
import '../../../models/chat_message.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/widgets/chat_folder_tabs.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../media/screens/media_viewer_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../settings/screens/chat_folders_settings_screen.dart';
import '../../settings/widgets/desktop_settings_list.dart';

/// Desktop layout breakpoint — screens wider than this use [DesktopLayout].
const double kDesktopBreakpoint = 720;

class DesktopLayout extends StatefulWidget {
  final UserModel user;

  const DesktopLayout({super.key, required this.user});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout>
    with WidgetsBindingObserver {
  // ── State ────────────────────────────────────────────────────────────────
  // Tabs: 0 = Chats, 1 = Calls, 2 = Profile, 3 = Settings
  int _selectedTab = 0;
  String _activeSettingsSection = 'chat_folders';
  late UserModel _currentUser;

  /// The active chat (right panel). Null = show placeholder.
  ChatScreen? _activeChatScreen;

  /// Detail or settings screen shown in the right panel (e.g. Chat Folders)
  Widget? _activeDetailScreen;

  final GlobalKey<ChatListScreenState> _chatListKey =
      GlobalKey<ChatListScreenState>();

  Map<int, ChatConversation> _convMap = {};
  List<UserModel> _allUsers = [];
  List<ChatGroup> _allGroups = [];

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;

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

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final cached = await LocalChatStorage.instance.getCachedConversations();
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _convMap = {for (final c in cached) c.user.id: c};
      });
    }
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
      _selectedTab = 0; // Chats tab
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
        availableUsers: users.isNotEmpty ? users : _allUsers,
        availableGroups: groups.isNotEmpty ? groups : _allGroups,
        onClose: () {
          setState(() {
            _activeDetailScreen = null;
            if (_selectedTab == 3) {
              _selectedTab = 0;
            }
          });
        },
      );
    });
  }

  void _handleDataUpdated({
    List<UserModel> users = const [],
    List<ChatGroup> groups = const [],
    Map<int, ChatConversation> convMap = const {},
  }) {
    if (mounted) {
      setState(() {
        _allUsers = users;
        _allGroups = groups;
        _convMap = convMap;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        ChatFolderController.instance,
      ]),
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        final primaryColor = ThemeController.instance.primaryColor;

        return Scaffold(
          backgroundColor: ThemeController.instance.scaffoldBg,
          body: SafeArea(
            bottom: false,
            child: _DesktopShell(
              folderRail: _buildFolderRail(),
              middlePanel: _buildMiddlePanel(isDark, primaryColor),
              rightPanel: _buildRightPanel(),
              activeChatScreen: _activeChatScreen,
            ),
          ),
        );
      },
    );
  }

  // ── Column 1: Folder Rail ─────────────────────────────────────────────────
  Widget? _buildFolderRail() {
    final controller = ChatFolderController.instance;
    if (!controller.isTabsOnLeft) return null;

    return ChatFolderLeftRail(
      users: _allUsers,
      groups: _allGroups,
      convMap: _convMap,
      onFolderSelected: (folder) {
        setState(() {
          _selectedTab = 0; // Chats tab
        });
        _chatListKey.currentState?.refresh();
      },
      onOpenSettings: () {
        setState(() {
          _selectedTab = 3; // Switch to Settings tab
          _activeSettingsSection = 'chat_folders';
          _openChatFoldersSettings();
        });
      },
    );
  }

  // ── Column 2: Middle Panel ────────────────────────────────────────────────
  Widget _buildMiddlePanel(bool isDark, Color primaryColor) {
    return Column(
      children: [
        // Tab body
        Expanded(child: _buildMiddleBody()),

        // 4-Tab navigation bar matching Telegram macOS
        _buildMiddleBottomBar(isDark, primaryColor),
      ],
    );
  }

  Widget _buildMiddleBody() {
    switch (_selectedTab) {
      case 0: // Chats
        return ChatListScreen(
          key: _chatListKey,
          currentUser: _currentUser,
          onOpenChat: _openChatWithUser,
          onOpenGroupChat: _openChatWithGroup,
          onOpenChatFolders: _openChatFoldersSettings,
          onDataUpdated: _handleDataUpdated,
        );
      case 1: // Calls / People
        return ContactsScreen(
          currentUser: _currentUser,
          onSelectUser: _openChatWithUser,
        );
      case 2: // Profile
        return ProfileScreen(currentUser: _currentUser);
      case 3: // Settings
        return DesktopSettingsList(
          currentUser: _currentUser,
          activeSection: _activeSettingsSection,
          onSelectSection: (section) {
            setState(() {
              _activeSettingsSection = section;
              if (section == 'chat_folders') {
                _openChatFoldersSettings();
              }
            });
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMiddleBottomBar(bool isDark, Color primaryColor) {
    final totalUnread = _convMap.values.fold<int>(0, (sum, c) => sum + c.unreadCount) +
        _allGroups.fold<int>(0, (sum, g) => sum + g.unreadCount);

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131822) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Profile (index 2)
          _buildBottomTabItem(
            tabIndex: 2,
            icon: CupertinoIcons.person_crop_circle,
            activeIcon: CupertinoIcons.person_crop_circle_fill,
            label: 'Profile',
            primaryColor: primaryColor,
            isDark: isDark,
          ),

          // 2. Calls / People (index 1)
          _buildBottomTabItem(
            tabIndex: 1,
            icon: CupertinoIcons.phone,
            activeIcon: CupertinoIcons.phone_fill,
            label: 'Calls',
            primaryColor: primaryColor,
            isDark: isDark,
          ),

          // 3. Chats (index 0)
          _buildBottomTabItem(
            tabIndex: 0,
            icon: CupertinoIcons.chat_bubble_2,
            activeIcon: CupertinoIcons.chat_bubble_2_fill,
            label: 'Chats',
            badgeCount: totalUnread,
            primaryColor: primaryColor,
            isDark: isDark,
          ),

          // 4. Settings (index 3)
          _buildBottomTabItem(
            tabIndex: 3,
            icon: CupertinoIcons.gear_alt,
            activeIcon: CupertinoIcons.gear_alt_fill,
            label: 'Settings',
            primaryColor: primaryColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabItem({
    required int tabIndex,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badgeCount,
    required Color primaryColor,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == tabIndex;
    final color = isSelected
        ? primaryColor
        : (isDark ? Colors.white54 : Colors.black45);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = tabIndex;
          if (tabIndex == 3) {
            _activeSettingsSection = 'chat_folders';
            _openChatFoldersSettings();
          } else if (tabIndex == 0) {
            _activeDetailScreen = null;
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: color,
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: -3,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Column 3: Right Panel ─────────────────────────────────────────────────
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
// Desktop shell: 3-column Telegram layout
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopShell extends StatelessWidget {
  final Widget? folderRail;
  final Widget middlePanel;
  final Widget rightPanel;
  final Widget? activeChatScreen;

  const _DesktopShell({
    this.folderRail,
    required this.middlePanel,
    required this.rightPanel,
    this.activeChatScreen,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 500) {
      return activeChatScreen ?? middlePanel;
    }

    return Row(
      children: [
        // 1 ── Column 1: Folder Rail (if Tabs on Left)
        if (folderRail != null) ...[
          folderRail!,
          _VerticalDivider(),
        ],

        // 2 ── Column 2: Middle Panel (Chat List or Settings with bottom tabs)
        SizedBox(
          width: _middlePanelWidth(width),
          child: middlePanel,
        ),

        // 3 ── Vertical Divider
        _VerticalDivider(),

        // 4 ── Column 3: Right Panel (Chat or Settings detail)
        Expanded(child: rightPanel),
      ],
    );
  }

  double _middlePanelWidth(double totalWidth) {
    if (totalWidth < 900) return 300;
    if (totalWidth < 1200) return 330;
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
