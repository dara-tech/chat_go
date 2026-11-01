import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_folder_model.dart';
import '../../models/chat_message.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';

/// Central state manager for Chat Folders, layout preference, and chat categorization.
class ChatFolderController extends ChangeNotifier {
  static final ChatFolderController instance = ChatFolderController._();
  ChatFolderController._();

  static const String _prefFoldersKey = 'chat_folders_list_v1';
  static const String _prefShowTagsKey = 'chat_folders_show_tags';
  static const String _prefTabsViewKey = 'chat_folders_tabs_view'; // 'top' or 'left'
  static const String _prefActiveFolderKey = 'chat_folders_active_id';

  List<ChatFolder> _folders = [];
  bool _showFolderTags = true;
  String _tabsView = 'top'; // 'top' or 'left'
  String _activeFolderId = 'all_chats';

  List<ChatFolder> get folders => List.unmodifiable(_folders);

  /// Folders excluding the internal "All Chats" when displaying custom folder list
  List<ChatFolder> get customFolders =>
      _folders.where((f) => f.id != 'all_chats').toList();

  bool get showFolderTags => _showFolderTags;
  String get tabsView => _tabsView;
  bool get isTabsOnLeft => _tabsView == 'left';
  bool get isTabsOnTop => _tabsView == 'top';
  String get activeFolderId => _activeFolderId;

  ChatFolder? get activeFolder {
    try {
      return _folders.firstWhere((f) => f.id == _activeFolderId);
    } catch (_) {
      return _folders.isNotEmpty ? _folders.first : null;
    }
  }

  /// Initialize state from SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _showFolderTags = prefs.getBool(_prefShowTagsKey) ?? true;
      _tabsView = prefs.getString(_prefTabsViewKey) ?? 'top';
      _activeFolderId = prefs.getString(_prefActiveFolderKey) ?? 'all_chats';

      final savedJson = prefs.getString(_prefFoldersKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedJson);
        _folders = decoded.map((e) => ChatFolder.fromJson(e)).toList();
      } else {
        _folders = ChatFolder.getDefaultFolders();
      }

      // Ensure "all_chats" is always present at order 0
      if (!_folders.any((f) => f.id == 'all_chats')) {
        _folders.insert(
          0,
          const ChatFolder(
            id: 'all_chats',
            name: 'All Chats',
            iconKey: 'chat',
            isSystem: true,
            order: 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ChatFolderController] init error: $e');
      _folders = ChatFolder.getDefaultFolders();
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefShowTagsKey, _showFolderTags);
      await prefs.setString(_prefTabsViewKey, _tabsView);
      await prefs.setString(_prefActiveFolderKey, _activeFolderId);

      final encoded = jsonEncode(_folders.map((f) => f.toJson()).toList());
      await prefs.setString(_prefFoldersKey, encoded);
    } catch (e) {
      debugPrint('[ChatFolderController] persist error: $e');
    }
  }

  void setActiveFolder(String folderId) {
    if (_activeFolderId != folderId) {
      _activeFolderId = folderId;
      _persist();
      notifyListeners();
    }
  }

  Future<void> setShowFolderTags(bool value) async {
    if (_showFolderTags != value) {
      _showFolderTags = value;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> setTabsView(String view) async {
    if (view != 'top' && view != 'left') return;
    if (_tabsView != view) {
      _tabsView = view;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> createFolder(ChatFolder folder) async {
    final nextOrder = _folders.length;
    _folders.add(folder.copyWith(order: nextOrder));
    notifyListeners();
    await _persist();
  }

  Future<void> updateFolder(ChatFolder updated) async {
    final index = _folders.indexWhere((f) => f.id == updated.id);
    if (index != -1) {
      _folders[index] = updated;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> deleteFolder(String folderId) async {
    if (folderId == 'all_chats') return; // Cannot delete All Chats
    _folders.removeWhere((f) => f.id == folderId);
    if (_activeFolderId == folderId) {
      _activeFolderId = 'all_chats';
    }
    notifyListeners();
    await _persist();
  }

  Future<void> reorderFolders(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _folders.length) return;
    if (newIndex < 0 || newIndex > _folders.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _folders.removeAt(oldIndex);
    _folders.insert(newIndex, item);

    for (int i = 0; i < _folders.length; i++) {
      _folders[i] = _folders[i].copyWith(order: i);
    }

    notifyListeners();
    await _persist();
  }

  /// Toggle inclusion of a user or group in a specific folder
  Future<void> toggleChatInFolder(String folderId, {int? userId, int? groupId}) async {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;

    final folder = _folders[idx];

    if (userId != null) {
      final users = List<int>.from(folder.includedUserIds);
      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }
      _folders[idx] = folder.copyWith(includedUserIds: users);
    } else if (groupId != null) {
      final groups = List<int>.from(folder.includedGroupIds);
      if (groups.contains(groupId)) {
        groups.remove(groupId);
      } else {
        groups.add(groupId);
      }
      _folders[idx] = folder.copyWith(includedGroupIds: groups);
    }

    notifyListeners();
    await _persist();
  }

  /// Returns whether a chat is explicitly or rule-wise included in a folder
  bool isChatInFolder(String folderId, {int? userId, int? groupId}) {
    final folder = _folders.cast<ChatFolder?>().firstWhere(
          (f) => f?.id == folderId,
          orElse: () => null,
        );
    if (folder == null) return false;
    if (folder.id == 'all_chats') return true;

    if (userId != null) {
      if (folder.includedUserIds.contains(userId)) return true;
      if (folder.excludedUserIds.contains(userId)) return false;
      return folder.includePersonal;
    }
    if (groupId != null) {
      if (folder.includedGroupIds.contains(groupId)) return true;
      if (folder.excludedGroupIds.contains(groupId)) return false;
      return folder.includeGroups;
    }
    return false;
  }

  /// Returns all custom folders that this chat is part of (for folder tags on tiles)
  List<ChatFolder> getFoldersForChat({
    UserModel? user,
    ChatGroup? group,
    ChatConversation? conv,
  }) {
    final result = <ChatFolder>[];
    for (final folder in customFolders) {
      if (matchesFolder(folder, user: user, group: group, conv: conv)) {
        result.add(folder);
      }
    }
    return result;
  }

  /// Evaluates whether a given conversation or contact matches a folder's rules
  bool matchesFolder(
    ChatFolder folder, {
    UserModel? user,
    ChatGroup? group,
    ChatConversation? conv,
  }) {
    if (folder.id == 'all_chats') return true;

    final unread = (conv?.unreadCount ?? 0) > 0 || (group?.unreadCount ?? 0) > 0;

    // Filter unread only
    if (folder.includeUnreadOnly && !unread) {
      return false;
    }

    if (folder.excludeRead && !unread) {
      return false;
    }

    // Direct User Chat
    if (user != null) {
      if (folder.excludedUserIds.contains(user.id)) return false;
      if (folder.includedUserIds.contains(user.id)) return true;

      // Special rule for "My Files" folder
      if (folder.id == 'my_files') {
        // Chat with self or saved messages or containing files
        return false;
      }

      // Special rule for "Personal"
      if (folder.id == 'personal') {
        return true;
      }

      return folder.includePersonal;
    }

    // Group Chat
    if (group != null) {
      if (folder.excludedGroupIds.contains(group.id)) return false;
      if (folder.includedGroupIds.contains(group.id)) return true;

      if (folder.id == 'personal') {
        return false;
      }

      return folder.includeGroups;
    }

    return false;
  }

  /// Calculates item count for a folder
  int calculateCountForFolder(
    ChatFolder folder, {
    required List<UserModel> users,
    required List<ChatGroup> groups,
    required Map<int, ChatConversation> convMap,
  }) {
    if (folder.id == 'all_chats') {
      return users.length + groups.length;
    }

    int count = 0;
    for (final u in users) {
      if (matchesFolder(folder, user: u, conv: convMap[u.id])) {
        count++;
      }
    }
    for (final g in groups) {
      if (matchesFolder(folder, group: g)) {
        count++;
      }
    }
    return count;
  }

  /// Checks if any chat in the folder has unread messages
  bool hasUnreadInFolder(
    ChatFolder folder, {
    required List<UserModel> users,
    required List<ChatGroup> groups,
    required Map<int, ChatConversation> convMap,
  }) {
    for (final u in users) {
      final conv = convMap[u.id];
      if ((conv?.unreadCount ?? 0) > 0 &&
          matchesFolder(folder, user: u, conv: conv)) {
        return true;
      }
    }
    for (final g in groups) {
      if (g.unreadCount > 0 && matchesFolder(folder, group: g)) {
        return true;
      }
    }
    return false;
  }
}

