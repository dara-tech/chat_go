import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/chat_folder_controller.dart';
import '../../../core/storage/local_chat_storage.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/websocket/chat_socket_service.dart';
import '../../../models/chat_message.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../../settings/screens/chat_folders_settings_screen.dart';
import '../widgets/add_to_folder_sheet.dart';
import '../widgets/chat_folder_tabs.dart';
import '../widgets/chat_list_tile.dart';
import '../widgets/chat_preview_modal.dart';
import '../widgets/create_group_sheet.dart';
import '../widgets/delete_chat_dialog.dart';
import 'chat_screen.dart';
import 'chat_search_screen.dart';

class ChatListScreen extends StatefulWidget {
  final UserModel currentUser;

  /// Optional override called instead of pushing a new route.
  /// Used by [DesktopLayout] to open the chat in the right panel.
  final void Function(UserModel user)? onOpenChat;

  /// Optional override called instead of pushing a new route for group chats.
  final void Function(ChatGroup group)? onOpenGroupChat;

  /// Optional override to open Chat Folders settings (e.g. inside desktop right panel).
  final void Function({List<UserModel> users, List<ChatGroup> groups})? onOpenChatFolders;

  const ChatListScreen({
    super.key,
    required this.currentUser,
    this.onOpenChat,
    this.onOpenGroupChat,
    this.onOpenChatFolders,
  });

  @override
  State<ChatListScreen> createState() => ChatListScreenState();
}

class ChatListScreenState extends State<ChatListScreen> {
  List<UserModel> _users = [];
  List<ChatConversation> _conversations = [];
  List<ChatGroup> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Groups', 'Online', 'Unread'
  StreamSubscription? _socketSubscription;
  StreamSubscription<List<ChatConversation>>? _storageSubscription;

  @override
  void initState() {
    super.initState();
    ChatSocketService.instance.connect();
    _initStorageListener();
    _loadLocalCacheFirst();
    _fetchData();
    _initSocketListener();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
  }

  void _initStorageListener() {
    _storageSubscription = LocalChatStorage.instance.conversationsStream.listen((updatedList) {
      if (!mounted) return;
      setState(() {
        _conversations = updatedList;
      });
    });
  }

  Future<void> _loadLocalCacheFirst() async {
    final cached = await LocalChatStorage.instance.getCachedConversations();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _conversations = cached;
        _isLoading = false;
      });
    }
  }

  void _initSocketListener() {
    _socketSubscription = ChatSocketService.instance.messageStream.listen((event) {
      if (!mounted) return;
      final type = event['type'];

      if (type == 'group_message') {
        final incomingGroupId = event['group_id'] is int
            ? event['group_id'] as int
            : int.tryParse(event['group_id']?.toString() ?? '');
        if (incomingGroupId != null) {
          final incomingMsg = ChatMessage.fromJson(event);
          setState(() {
            final idx = _groups.indexWhere((g) => g.id == incomingGroupId);
            if (idx != -1) {
              final g = _groups[idx];
              final isMe = incomingMsg.senderId == widget.currentUser.id;
              _groups[idx] = g.copyWith(
                lastMessage: incomingMsg,
                updatedAt: incomingMsg.timestamp,
                unreadCount: isMe ? g.unreadCount : g.unreadCount + 1,
              );
            }
          });
        }
        _syncWithServer();
      } else if (type == 'chat_message') {
        final senderId = event['sender_id'] as int?;
        final receiverId = event['receiver_id'] as int?;
        final myId = widget.currentUser.id;

        int? otherId;
        if (senderId == myId && receiverId != null && receiverId != 0) {
          otherId = receiverId;
        } else if (receiverId == myId && senderId != null) {
          otherId = senderId;
        }

        if (otherId != null) {
          final incomingMsg = ChatMessage.fromJson(event);
          LocalChatStorage.instance.updateFromIncomingMessage(
            message: incomingMsg,
            currentUserId: myId,
          );
        }
      } else if (type == 'user_status') {
        final userId = event['user_id'] is int
            ? event['user_id'] as int
            : int.tryParse(event['user_id']?.toString() ?? '') ?? 0;
        final isOnline = event['is_online'] == true || event['payload']?['is_online'] == true;
        if (userId != 0) {
          setState(() {
            _users = _users.map((u) {
              if (u.id == userId) {
                return u.copyWith(isOnline: isOnline);
              }
              return u;
            }).toList();

            _conversations = _conversations.map((c) {
              if (c.user.id == userId) {
                return c.copyWith(user: c.user.copyWith(isOnline: isOnline));
              }
              return c;
            }).toList();
          });
        }
      } else if (type == 'online_users_snapshot') {
        final onlineIds = ChatSocketService.instance.onlineUserIds;
        setState(() {
          _users = _users.map((u) {
            return u.copyWith(isOnline: onlineIds.contains(u.id));
          }).toList();

          _conversations = _conversations.map((c) {
            return c.copyWith(user: c.user.copyWith(isOnline: onlineIds.contains(c.user.id)));
          }).toList();
        });
      } else if (type == 'read_receipt' || type == 'messages_read') {
        final rawReaderId = event['reader_id'] ?? event['sender_id'];
        final readerId = rawReaderId is int
            ? rawReaderId
            : int.tryParse(rawReaderId?.toString() ?? '');
        if (readerId != null && readerId > 0) {
          if (readerId == widget.currentUser.id) {
            // Current user marked chat read on another device/screen
            final rawPartnerId = event['receiver_id'];
            final partnerId = rawPartnerId is int
                ? rawPartnerId
                : int.tryParse(rawPartnerId?.toString() ?? '');
            if (partnerId != null && partnerId > 0) {
              LocalChatStorage.instance.markConversationAsRead(partnerId);
            }
          } else {
            // Partner read messages sent by current user
            LocalChatStorage.instance.updateFromReadReceipt(
              readerId: readerId,
              currentUserId: widget.currentUser.id,
            );
          }
        }
      } else if (type == 'message_reaction') {
        final targetId = (event['message_id'] ?? event['id'] ?? event['payload']?['message_id'])?.toString();
        final reactions = (event['reactions'] ?? event['payload']?['reactions'])?.toString();
        if (targetId != null && reactions != null) {
          LocalChatStorage.instance.updateMessageReaction(
            messageId: targetId,
            reactions: reactions,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _storageSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _syncWithServer();

  Future<void> _fetchData() => _syncWithServer();

  Future<void> _syncWithServer() async {
    try {
      final futures = await Future.wait([
        ApiClient.instance.listUsers(limit: 100),
        ApiClient.instance.getConversations(),
        ApiClient.instance.getGroups(),
      ]);

      if (mounted) {
        final allUsers = futures[0] as List<UserModel>;
        final conversations = futures[1] as List<ChatConversation>;
        final groups = futures[2] as List<ChatGroup>;

        final onlineIds = ChatSocketService.instance.onlineUserIds;
        setState(() {
          _users = allUsers
              .where((u) => u.username != widget.currentUser.username)
              .map((u) => u.copyWith(isOnline: onlineIds.contains(u.id) || u.isOnline == true))
              .toList();
          _groups = groups;
          _isLoading = false;
          _errorMessage = null;
        });

        await LocalChatStorage.instance.saveConversations(conversations);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_conversations.isEmpty && _users.isEmpty && _groups.isEmpty) {
            _errorMessage = 'Could not load chats. Pull down to retry.';
          }
        });
      }
    }
  }

  Future<void> _openCreateGroupSheet() async {
    final created = await CreateGroupSheet.show(
      context: context,
      currentUser: widget.currentUser,
    );
    if (created != null && mounted) {
      _syncWithServer();
      _openGroupChat(created);
    }
  }

  Future<void> _openGroupChat(ChatGroup group) async {
    setState(() {
      final idx = _groups.indexWhere((g) => g.id == group.id);
      if (idx != -1) {
        _groups[idx] = _groups[idx].copyWith(unreadCount: 0);
      }
    });

    // Desktop: delegate to parent callback instead of pushing a route.
    if (widget.onOpenGroupChat != null) {
      widget.onOpenGroupChat!(group);
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(
          currentUser: widget.currentUser,
          group: group,
          title: group.name,
        ),
      ),
    );
    if (mounted) {
      _syncWithServer();
    }
  }

  Future<void> _openChat({required String title, UserModel? chatUser}) async {
    if (chatUser != null) {
      await LocalChatStorage.instance.markConversationAsRead(chatUser.id);
    }

    // Desktop: delegate to parent callback instead of pushing a route.
    if (chatUser != null && widget.onOpenChat != null) {
      widget.onOpenChat!(chatUser);
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(
          currentUser: widget.currentUser,
          title: title,
          chatUser: chatUser,
        ),
      ),
    );

    if (mounted) {
      _loadLocalCacheFirst();
    }
  }

  void _showConversationOptions(UserModel user, ChatConversation? conv) {
    final convId = conv?.conversationId ?? 'chat_${user.id}';

    ChatPreviewModal.show(
      context: context,
      currentUser: widget.currentUser,
      partnerUser: user,
      conversation: conv,
      onOpenChat: () {
        _openChat(
          title: user.displayName.isNotEmpty ? user.displayName : user.username,
          chatUser: user,
        );
      },
      onTogglePin: () async {
        await LocalChatStorage.instance.togglePin(convId);
      },
      onToggleMute: () async {
        await LocalChatStorage.instance.toggleMute(convId);
      },
      onToggleRead: () async {
        await LocalChatStorage.instance.markConversationAsRead(user.id);
      },
      onDelete: () => _confirmDeleteChat(user),
    );
  }

  Future<void> _confirmDeleteChat(UserModel user) async {
    final partnerName = user.displayName.isNotEmpty ? user.displayName : user.username;
    final res = await DeleteChatDialog.show(context, partnerName: partnerName);
    if (res != null) {
      try {
        await ApiClient.instance.deleteConversation(user.id, forEveryone: res.deleteForEveryone);
      } catch (_) {}
      await LocalChatStorage.instance.clearChat(user.id);
      if (mounted) {
        setState(() {
          _conversations.removeWhere((c) => c.user.id == user.id);
        });
      }
      _fetchData();
    }
  }

  Future<void> _openSearchScreen() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatSearchScreen(
          currentUser: widget.currentUser,
          initialUsers: _users,
        ),
      ),
    );
    if (mounted) {
      _loadLocalCacheFirst();
    }
  }

  void _handleOpenChatFolders() {
    if (widget.onOpenChatFolders != null) {
      widget.onOpenChatFolders!(users: _users, groups: _groups);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatFoldersSettingsScreen(
            availableUsers: _users,
            availableGroups: _groups,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final convMap = <int, ChatConversation>{};
    for (final c in _conversations) {
      convMap[c.user.id] = c;
    }

    final allAvailableUsers = <int, UserModel>{};
    for (final c in _conversations) {
      if (c.user.username != widget.currentUser.username) {
        allAvailableUsers[c.user.id] = c.user;
      }
    }
    for (final u in _users) {
      if (u.username != widget.currentUser.username) {
        allAvailableUsers.putIfAbsent(u.id, () => u);
      }
    }

    final items = <_ChatItem>[];
    final activeFolder = ChatFolderController.instance.activeFolder;
    final isFilteringByFolder = activeFolder != null && activeFolder.id != 'all_chats';

    if (isFilteringByFolder) {
      final filteredUsers = allAvailableUsers.values.where((u) {
        if (_searchQuery.isNotEmpty) {
          final matches = u.displayName.toLowerCase().contains(_searchQuery) ||
              u.username.toLowerCase().contains(_searchQuery);
          if (!matches) return false;
        }
        return ChatFolderController.instance.matchesFolder(
          activeFolder,
          user: u,
          conv: convMap[u.id],
        );
      });

      for (final u in filteredUsers) {
        items.add(_ChatItem.user(user: u, conv: convMap[u.id]));
      }

      final filteredGroups = _groups.where((g) {
        if (_searchQuery.isNotEmpty) {
          final matches = g.name.toLowerCase().contains(_searchQuery);
          if (!matches) return false;
        }
        return ChatFolderController.instance.matchesFolder(
          activeFolder,
          group: g,
        );
      });

      for (final g in filteredGroups) {
        items.add(_ChatItem.group(g));
      }
    } else {
      if (_activeFilter != 'Groups') {
        final filteredUsers = allAvailableUsers.values.where((u) {
          if (_searchQuery.isNotEmpty) {
            final matches = u.displayName.toLowerCase().contains(_searchQuery) ||
                u.username.toLowerCase().contains(_searchQuery);
            if (!matches) return false;
          }
          if (_activeFilter == 'Online') {
            return u.isOnline == true;
          }
          if (_activeFilter == 'Unread') {
            final conv = convMap[u.id];
            return conv != null && conv.unreadCount > 0;
          }
          return true;
        });

        for (final u in filteredUsers) {
          items.add(_ChatItem.user(user: u, conv: convMap[u.id]));
        }
      }

      if (_activeFilter == 'All' || _activeFilter == 'Groups' || _activeFilter == 'Unread') {
        final filteredGroups = _groups.where((g) {
          if (_activeFilter == 'Unread' && g.unreadCount <= 0) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            return g.name.toLowerCase().contains(_searchQuery);
          }
          return true;
        });

        for (final g in filteredGroups) {
          items.add(_ChatItem.group(g));
        }
      }
    }

    items.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      final timeA = a.lastTime;
      final timeB = b.lastTime;

      if (timeA != null && timeB != null) {
        return timeB.compareTo(timeA);
      }
      if (timeA != null && timeB == null) return -1;
      if (timeA == null && timeB != null) return 1;

      if (a.user != null && b.user != null) {
        final onlineA = a.user!.isOnline == true;
        final onlineB = b.user!.isOnline == true;
        if (onlineA && !onlineB) return -1;
        if (!onlineA && onlineB) return 1;
        return a.user!.displayName.toLowerCase().compareTo(b.user!.displayName.toLowerCase());
      }
      if (a.group != null && b.group != null) {
        return a.group!.name.toLowerCase().compareTo(b.group!.name.toLowerCase());
      }
      return 0;
    });

    final onlineCount = _users.where((u) => u.isOnline == true).length;
    final folderCtrl = ChatFolderController.instance;

    return ListenableBuilder(
      listenable: folderCtrl,
      builder: (context, _) {
        final isTabsLeft = folderCtrl.isTabsOnLeft;

        return Column(
          children: [
            ValueListenableBuilder<SocketConnectionState>(
              valueListenable: ChatSocketService.instance.connectionStateNotifier,
              builder: (context, connState, _) {
                if (connState == SocketConnectionState.connected) {
                  return const SizedBox.shrink();
                }

                final isReconnecting = connState == SocketConnectionState.reconnecting ||
                    connState == SocketConnectionState.connecting;
                final text = isReconnecting ? 'Connecting...' : 'Waiting for connection...';

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.92),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CupertinoActivityIndicator(radius: 6, color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            _buildHeader(onlineCount),

            // Top Folder Tabs (when "Tabs at the top" is active)
            if (!isTabsLeft)
              ChatFolderTopBar(
                users: _users,
                groups: _groups,
                convMap: convMap,
                onFolderSelected: (_) => setState(() {}),
                onOpenSettings: _handleOpenChatFolders,
              ),

            // Sub-filter chips only if inside All Chats
            if (folderCtrl.activeFolderId == 'all_chats')
              _buildFilterChips(onlineCount),

            Divider(
              height: 1,
              thickness: 0.8,
              indent: 0,
              endIndent: 0,
              color: LiquidGlassTheme.dividerHairline,
            ),
            Expanded(
              child: Row(
                children: [
                  // Left Folder Rail (when "Tabs on the left" is active)
                  if (isTabsLeft)
                    ChatFolderLeftRail(
                      users: _users,
                      groups: _groups,
                      convMap: convMap,
                      onFolderSelected: (_) => setState(() {}),
                      onOpenSettings: _handleOpenChatFolders,
                    ),

                  Expanded(
                    child: _isLoading && _conversations.isEmpty && _users.isEmpty && _groups.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(LiquidGlassTheme.accentBlue),
                            ),
                          )
                        : _errorMessage != null && _conversations.isEmpty && _users.isEmpty && _groups.isEmpty
                            ? _buildErrorView()
                            : RefreshIndicator(
                                onRefresh: () async {
                                  ChatSocketService.instance.connect();
                                  await _fetchData();
                                },
                                color: LiquidGlassTheme.accentBlue,
                                child: items.isEmpty
                                    ? _buildEmptyFilteredState()
                                    : ListView.separated(
                                        physics: const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                        padding: const EdgeInsets.only(top: 4, bottom: 92),
                                        itemCount: items.length,
                                        separatorBuilder: (context, index) => Divider(
                                          height: 1,
                                          thickness: 0.8,
                                          indent: 74,
                                          endIndent: 0,
                                          color: LiquidGlassTheme.dividerHairline,
                                        ),
                                        itemBuilder: (context, index) {
                                          final item = items[index];
                                          if (item.group != null) {
                                            final g = item.group!;
                                            return ChatListTile(
                                              group: g,
                                              currentUser: widget.currentUser,
                                              onTap: () => _openGroupChat(g),
                                              onLongPress: () => AddToFolderSheet.show(context, group: g),
                                            );
                                          }
                                          final user = item.user!;
                                          final conv = item.conv;
                                          return ChatListTile(
                                            user: user,
                                            conv: conv,
                                            currentUser: widget.currentUser,
                                            onTap: () => _openChat(title: user.displayName, chatUser: user),
                                            onLongPress: () => _showConversationOptions(user, conv),
                                          );
                                        },
                                      ),
                              ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int onlineCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                'Chats',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: LiquidGlassTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_users.length + _groups.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlassTheme.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _handleOpenChatFolders,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.folder_fill,
                    size: 17,
                    color: LiquidGlassTheme.accentBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openCreateGroupSheet,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.person_2_fill,
                    size: 17,
                    color: LiquidGlassTheme.accentBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openSearchScreen,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.search,
                    size: 17,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int onlineCount) {
    final totalUnread = _conversations.where((c) => c.unreadCount > 0).length +
        _groups.where((g) => g.unreadCount > 0).length;

    final filters = [
      {'label': 'All', 'count': _users.length + _groups.length},
      {'label': 'Groups', 'count': _groups.length},
      {'label': 'Online', 'count': onlineCount},
      {'label': 'Unread', 'count': totalUnread},
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final label = filter['label'] as String;
          final count = filter['count'] as int;
          final isSelected = _activeFilter == label;

          return GestureDetector(
            onTap: () => setState(() => _activeFilter = label),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? LiquidGlassTheme.accentBlue
                    : LiquidGlassTheme.inputFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? LiquidGlassTheme.accentBlue
                      : LiquidGlassTheme.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : LiquidGlassTheme.textSecondary,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : LiquidGlassTheme.borderSubtle,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : LiquidGlassTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
              ),
              child: Icon(
                CupertinoIcons.chat_bubble_2,
                color: LiquidGlassTheme.textMuted,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _activeFilter == 'Unread'
                  ? 'No unread messages'
                  : (_activeFilter == 'Online'
                      ? 'No contacts online'
                      : (_activeFilter == 'Groups' ? 'No groups yet' : 'No chats found')),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _activeFilter == 'Unread'
                  ? 'All caught up! Check the All tab for chats.'
                  : (_activeFilter == 'Groups'
                      ? 'Tap the group icon above to create your first group!'
                      : 'Start a conversation with any contact.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: LiquidGlassTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.wifi_exclamationmark,
              size: 40,
              color: LiquidGlassTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load conversations',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: LiquidGlassTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatItem {
  final UserModel? user;
  final ChatConversation? conv;
  final ChatGroup? group;
  final DateTime? lastTime;
  final bool isPinned;
  final int unreadCount;

  _ChatItem.user({required this.user, this.conv})
      : group = null,
        lastTime = conv?.lastMessageAt ?? conv?.lastMessage?.timestamp,
        isPinned = conv?.isPinned == true,
        unreadCount = conv?.unreadCount ?? 0;

  _ChatItem.group(this.group)
      : user = null,
        conv = null,
        lastTime = group?.lastMessage?.timestamp ?? group?.createdAt,
        isPinned = false,
        unreadCount = group?.unreadCount ?? 0;
}

