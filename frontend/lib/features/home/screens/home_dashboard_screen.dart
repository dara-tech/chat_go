import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/websocket/chat_socket_service.dart';
import 'package:frontend/core/notifications/notification_alert_service.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/widgets/clay_menu_bar.dart';
import 'package:frontend/features/chat/screens/chat_list_screen.dart';
import 'package:frontend/features/chat/screens/chat_screen.dart';
import 'package:frontend/core/services/media_download_service.dart';
import 'package:frontend/features/contacts/screens/contacts_screen.dart';
import 'package:frontend/features/media/screens/media_viewer_screen.dart';
import 'package:frontend/features/profile/screens/profile_screen.dart';
import 'desktop_layout.dart';

class HomeDashboardScreen extends StatefulWidget {
  final UserModel user;

  const HomeDashboardScreen({super.key, required this.user});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> with WidgetsBindingObserver {
  int _currentTabIndex = 0;
  late UserModel _currentUser;
  final GlobalKey<ChatListScreenState> _chatListKey = GlobalKey<ChatListScreenState>();

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

  void _onTabChanged(int index) {
    if (_currentTabIndex != index) {
      setState(() => _currentTabIndex = index);
    }
  }

  Future<void> _openChatWithUser(UserModel user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUser: _currentUser,
          title: user.displayName,
          chatUser: user,
        ),
      ),
    );
    if (mounted) {
      setState(() => _currentTabIndex = 0);
      _chatListKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= kDesktopBreakpoint;

    // ── Desktop: two-panel layout with sidebar nav rail ──────────────────
    if (isDesktop) {
      return DesktopLayout(user: _currentUser);
    }

    // ── Mobile: existing bottom-nav floating capsule layout ───────────────
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: ThemeController.instance.scaffoldBg,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Active Tab (ChatListScreen, ContactsScreen, ProfileScreen)
                Positioned.fill(
                  child: IndexedStack(
                    index: _currentTabIndex,
                    children: [
                      ChatListScreen(key: _chatListKey, currentUser: _currentUser),
                      ContactsScreen(
                        currentUser: _currentUser,
                        onSelectUser: _openChatWithUser,
                      ),
                      ProfileScreen(currentUser: _currentUser),
                    ],
                  ),
                ),

                // Blurred Frosted Bottom Navigation Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClayMenuBar(
                    currentIndex: _currentTabIndex,
                    onTabSelected: _onTabChanged,
                    items: const [
                      ClayMenuBarItem(
                        icon: CupertinoIcons.chat_bubble_2,
                        activeIcon: CupertinoIcons.chat_bubble_2_fill,
                        label: 'Chats',
                      ),
                      ClayMenuBarItem(
                        icon: CupertinoIcons.person_2,
                        activeIcon: CupertinoIcons.person_2_fill,
                        label: 'People',
                      ),
                      ClayMenuBarItem(
                        icon: CupertinoIcons.person_crop_circle,
                        activeIcon: CupertinoIcons.person_crop_circle_fill,
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
