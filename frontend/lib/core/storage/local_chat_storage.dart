import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/chat_message.dart';
import '../../models/user_model.dart';

/// LocalChatStorage handles:
/// 1. Local caching of conversation summaries for instant UI rendering (zero network wait).
/// 2. Reactive stream to refresh UI automatically.
/// 3. Incremental updates on WebSocket events (updating affected conversation without reloading the full list).
/// 4. Pinned and muted conversation states.
/// 5. Message history caching for instant chat rendering.
class LocalChatStorage {
  static final LocalChatStorage instance = LocalChatStorage._();
  LocalChatStorage._();

  SharedPreferences? _prefs;

  static const String _keyConversations = 'local_cache_conversations_v3';
  static const String _kPinnedIdsKey = 'chat_pinned_conversation_ids_v1';
  static const String _kMutedIdsKey = 'chat_muted_conversation_ids_v1';

  final StreamController<List<ChatConversation>> _conversationsController =
      StreamController<List<ChatConversation>>.broadcast();

  Stream<List<ChatConversation>> get conversationsStream =>
      _conversationsController.stream;

  List<ChatConversation> _memoryConversations = [];
  final Set<String> _pinnedIds = {};
  final Set<String> _mutedIds = {};
  bool _isLoaded = false;

  List<ChatConversation> get currentConversations => List.unmodifiable(_memoryConversations);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadFromLocal();
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _loadFromLocal() async {
    if (_isLoaded) return;
    try {
      final prefs = await _getPrefs();

      final pinnedList = prefs.getStringList(_kPinnedIdsKey) ?? [];
      _pinnedIds.clear();
      _pinnedIds.addAll(pinnedList);

      final mutedList = prefs.getStringList(_kMutedIdsKey) ?? [];
      _mutedIds.clear();
      _mutedIds.addAll(mutedList);

      final raw = prefs.getString(_keyConversations);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List?;
        if (decoded != null) {
          _memoryConversations = decoded.map((e) {
            final c = ChatConversation.fromJson(e as Map<String, dynamic>);
            final isPinned = _pinnedIds.contains(c.conversationId);
            final isMuted = _mutedIds.contains(c.conversationId);
            return c.copyWith(isPinned: isPinned, isMuted: isMuted);
          }).toList();
          _sortConversations();
        }
      }
      _isLoaded = true;
      _emitUpdate();
    } catch (_) {
      _isLoaded = true;
    }
  }

  // --- Conversations Cache & Sync ---

  /// Instant cached conversations for startup (zero network latency)
  Future<List<ChatConversation>> getCachedConversations() async {
    if (!_isLoaded) {
      await _loadFromLocal();
    }
    return List.unmodifiable(_memoryConversations);
  }

  /// Synchronize with server: updates local database and notifies stream
  Future<void> saveConversations(List<ChatConversation> serverConversations) async {
    await _loadFromLocal();

    final Map<String, ChatConversation> merged = {};

    // 1. Process server items, apply local pin/mute overrides if present
    for (final sConv in serverConversations) {
      final isPinned = _pinnedIds.contains(sConv.conversationId) || sConv.isPinned;
      final isMuted = _mutedIds.contains(sConv.conversationId) || sConv.isMuted;
      merged[sConv.conversationId] = sConv.copyWith(
        isPinned: isPinned,
        isMuted: isMuted,
      );
      if (isPinned) _pinnedIds.add(sConv.conversationId);
      if (isMuted) _mutedIds.add(sConv.conversationId);
    }

    // 2. Keep local conversations not yet on server
    for (final lConv in _memoryConversations) {
      merged.putIfAbsent(lConv.conversationId, () => lConv);
    }

    _memoryConversations = merged.values.toList();
    _sortConversations();
    _emitUpdate();
    await _persistConversations();
  }

  /// Incremental update: called when a new message arrives over WebSocket.
  /// Modifies only the affected conversation, updates unread count and timestamp,
  /// and moves it to the top of unpinned conversations (or within pinned).
  Future<void> updateFromIncomingMessage({
    required ChatMessage message,
    required int currentUserId,
    bool isChatOpen = false,
    UserModel? partnerFallback,
  }) async {
    await _loadFromLocal();

    final isIncoming = message.senderId != currentUserId;
    final partnerId = isIncoming ? message.senderId : message.receiverId;
    if (partnerId <= 0) return;

    final convId = 'chat_$partnerId';
    final existingIdx = _memoryConversations.indexWhere(
      (c) => c.conversationId == convId || c.user.id == partnerId,
    );

    ChatConversation updatedConv;

    if (existingIdx != -1) {
      final old = _memoryConversations[existingIdx];
      final newUnreadCount = (isIncoming && !isChatOpen)
          ? old.unreadCount + 1
          : (isChatOpen ? 0 : old.unreadCount);

      updatedConv = old.copyWith(
        lastMessage: message,
        lastMessageText: message.content,
        lastMessageAt: message.timestamp,
        lastMessageId: message.id,
        unreadCount: newUnreadCount,
      );
      _memoryConversations.removeAt(existingIdx);
    } else {
      final partnerUser = partnerFallback ??
          UserModel(
            id: partnerId,
            uuid: '$partnerId',
            username: message.username.isNotEmpty ? message.username : 'User $partnerId',
            email: '',
            displayName: message.username.isNotEmpty ? message.username : 'User $partnerId',
            avatarUrl: message.senderAvatar ?? '',
            isOnline: false,
            lastSeenAt: null,
            createdAt: DateTime.now(),
          );

      final isPinned = _pinnedIds.contains(convId);
      final isMuted = _mutedIds.contains(convId);

      updatedConv = ChatConversation(
        conversationId: convId,
        name: partnerUser.displayName.isNotEmpty ? partnerUser.displayName : partnerUser.username,
        avatarUrl: partnerUser.avatarUrl,
        lastMessage: message,
        lastMessageText: message.content,
        lastMessageAt: message.timestamp,
        lastMessageId: message.id,
        unreadCount: (isIncoming && !isChatOpen) ? 1 : 0,
        isPinned: isPinned,
        isMuted: isMuted,
        user: partnerUser,
      );
    }

    // Insert updated conversation in correct position:
    // If pinned: placed at top
    // If unpinned: placed right after pinned conversations
    if (updatedConv.isPinned) {
      _memoryConversations.insert(0, updatedConv);
    } else {
      final firstUnpinned = _memoryConversations.indexWhere((c) => c.isPinned != true);
      if (firstUnpinned == -1) {
        _memoryConversations.add(updatedConv);
      } else {
        _memoryConversations.insert(firstUnpinned, updatedConv);
      }
    }

    _sortConversations();
    _emitUpdate();
    await _persistConversations();
  }

  /// Incremental update for read receipt
  Future<void> updateFromReadReceipt({
    required int readerId,
    required int currentUserId,
  }) async {
    await _loadFromLocal();
    bool updated = false;

    for (var i = 0; i < _memoryConversations.length; i++) {
      final c = _memoryConversations[i];
      if (c.user.id == readerId) {
        if (c.lastMessage != null && c.lastMessage!.senderId == currentUserId) {
          _memoryConversations[i] = c.copyWith(
            lastMessage: c.lastMessage!.copyWith(isRead: true),
          );
          updated = true;
        }
      }
    }

    if (updated) {
      _emitUpdate();
      await _persistConversations();
    }

    // Also update cached message records for this partner
    try {
      final cached = await getCachedMessages(readerId);
      if (cached.isNotEmpty) {
        bool msgsUpdated = false;
        for (final m in cached) {
          if (m['sender_id'] == currentUserId && m['is_read'] != true) {
            m['is_read'] = true;
            msgsUpdated = true;
          }
        }
        if (msgsUpdated) {
          await saveMessages(readerId, cached);
        }
      }
    } catch (_) {}
  }

  /// Mark conversation as read locally
  Future<void> markConversationAsRead(int partnerId) async {
    await _loadFromLocal();
    final idx = _memoryConversations.indexWhere((c) => c.user.id == partnerId);
    if (idx != -1 && _memoryConversations[idx].unreadCount > 0) {
      _memoryConversations[idx] = _memoryConversations[idx].copyWith(unreadCount: 0);
      _emitUpdate();
      await _persistConversations();
    }
  }

  /// Incremental update for message reaction
  Future<void> updateMessageReaction({
    required String messageId,
    required String reactions,
    int? partnerId,
  }) async {
    await _loadFromLocal();
    bool updated = false;

    for (var i = 0; i < _memoryConversations.length; i++) {
      final c = _memoryConversations[i];
      if (c.lastMessage != null && c.lastMessage!.id.toString() == messageId) {
        _memoryConversations[i] = c.copyWith(
          lastMessage: c.lastMessage!.copyWith(reactions: reactions),
        );
        updated = true;
        break;
      }
    }

    if (updated) {
      _emitUpdate();
      await _persistConversations();
    }

    if (partnerId != null && partnerId > 0) {
      try {
        final cached = await getCachedMessages(partnerId);
        if (cached.isNotEmpty) {
          final idx = cached.indexWhere((m) => m['id']?.toString() == messageId);
          if (idx != -1) {
            cached[idx]['reactions'] = reactions;
            await saveMessages(partnerId, cached);
          }
        }
      } catch (_) {}
    }
  }

  /// Toggle pin status for a conversation
  Future<void> togglePin(String conversationId) async {
    await _loadFromLocal();
    final idx = _memoryConversations.indexWhere((c) => c.conversationId == conversationId);
    if (idx != -1) {
      final current = _memoryConversations[idx];
      final newPinned = !current.isPinned;
      _memoryConversations[idx] = current.copyWith(isPinned: newPinned);

      if (newPinned) {
        _pinnedIds.add(conversationId);
      } else {
        _pinnedIds.remove(conversationId);
      }

      _sortConversations();
      _emitUpdate();

      try {
        final prefs = await _getPrefs();
        await prefs.setStringList(_kPinnedIdsKey, _pinnedIds.toList());
      } catch (_) {}

      await _persistConversations();
    }
  }

  /// Toggle mute status for a conversation
  Future<void> toggleMute(String conversationId) async {
    await _loadFromLocal();
    final idx = _memoryConversations.indexWhere((c) => c.conversationId == conversationId);
    if (idx != -1) {
      final current = _memoryConversations[idx];
      final newMuted = !current.isMuted;
      _memoryConversations[idx] = current.copyWith(isMuted: newMuted);

      if (newMuted) {
        _mutedIds.add(conversationId);
      } else {
        _mutedIds.remove(conversationId);
      }

      _emitUpdate();

      try {
        final prefs = await _getPrefs();
        await prefs.setStringList(_kMutedIdsKey, _mutedIds.toList());
      } catch (_) {}

      await _persistConversations();
    }
  }

  /// Check if a conversation or user id is muted
  bool isConversationMuted(dynamic partnerIdOrConvId) {
    if (partnerIdOrConvId == null) return false;
    final id = partnerIdOrConvId.toString();
    return _mutedIds.contains(id) ||
        _memoryConversations.any((c) => c.conversationId == id && c.isMuted);
  }

  void _sortConversations() {
    _memoryConversations.sort((a, b) {
      // 1. Pinned conversations on top
      final isPinnedA = a.isPinned == true;
      final isPinnedB = b.isPinned == true;
      if (isPinnedA && !isPinnedB) return -1;
      if (!isPinnedA && isPinnedB) return 1;

      // 2. Sort by lastMessageAt descending
      final timeA = a.lastMessageAt ?? a.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = b.lastMessageAt ?? b.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });
  }

  void _emitUpdate() {
    if (!_conversationsController.isClosed) {
      _conversationsController.add(List.unmodifiable(_memoryConversations));
    }
  }

  Future<void> _persistConversations() async {
    try {
      final prefs = await _getPrefs();
      final jsonList = _memoryConversations.map((c) => c.toJson()).toList();
      await prefs.setString(_keyConversations, jsonEncode(jsonList));
    } catch (_) {}
  }

  // --- Messages Cache per Partner / Chat ---
  String _messageKey(int partnerId) => 'local_cache_msgs_$partnerId';

  Future<void> saveMessages(int partnerId, List<Map<String, dynamic>> messages, {int maxSaved = 100}) async {
    try {
      final prefs = await _getPrefs();
      final slice = messages.length > maxSaved ? messages.sublist(0, maxSaved) : messages;
      await prefs.setString(_messageKey(partnerId), jsonEncode(slice));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(int partnerId) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_messageKey(partnerId));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List?;
      if (decoded == null) return [];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  String _groupMessageKey(int groupId) => 'local_cache_group_msgs_$groupId';

  Future<void> saveGroupMessages(int groupId, List<Map<String, dynamic>> messages) async {
    try {
      final prefs = await _getPrefs();
      final toSave = messages.take(60).toList();
      await prefs.setString(_groupMessageKey(groupId), jsonEncode(toSave));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCachedGroupMessages(int groupId) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_groupMessageKey(groupId));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List?;
      if (decoded == null) return [];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearChat(int partnerId) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_messageKey(partnerId));
      _memoryConversations.removeWhere((c) => c.user.id == partnerId);
      await _persistConversations();
      _emitUpdate();
    } catch (_) {}
  }

  // --- Profile Cache & Stream (SQLite / Local Storage) ---
  final Map<int, UserModel> _cachedProfiles = {};
  final StreamController<UserModel> _profileUpdatesController =
      StreamController<UserModel>.broadcast();

  String _profileKey(int userId) => 'local_cache_user_profile_$userId';

  /// Synchronous in-memory lookup or disk retrieval (instant 0ms)
  Future<UserModel?> getCachedUserProfile(int userId) async {
    if (_cachedProfiles.containsKey(userId)) {
      return _cachedProfiles[userId];
    }
    // Check conversations memory
    for (final c in _memoryConversations) {
      if (c.user.id == userId) {
        _cachedProfiles[userId] = c.user;
        return c.user;
      }
    }
    // Check persistent storage
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_profileKey(userId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final user = UserModel.fromJson(decoded);
        _cachedProfiles[userId] = user;
        return user;
      }
    } catch (_) {}
    return null;
  }

  /// Observes real-time updates for a specific user ID
  Stream<UserModel> watchUserProfile(int userId) async* {
    final cached = await getCachedUserProfile(userId);
    if (cached != null) {
      yield cached;
    }
    yield* _profileUpdatesController.stream.where((u) => u.id == userId);
  }

  /// Reconciles and saves an updated profile to local database and notifies listeners
  Future<void> saveUserProfile(UserModel profile) async {
    _cachedProfiles[profile.id] = profile;

    // Reconcile matching conversation in memory if present
    bool convUpdated = false;
    for (var i = 0; i < _memoryConversations.length; i++) {
      if (_memoryConversations[i].user.id == profile.id) {
        _memoryConversations[i] = _memoryConversations[i].copyWith(
          name: profile.displayName.isNotEmpty ? profile.displayName : profile.username,
          avatarUrl: profile.avatarUrl,
          user: profile,
        );
        convUpdated = true;
      }
    }

    if (convUpdated) {
      _emitUpdate();
      unawaited(_persistConversations());
    }

    _profileUpdatesController.add(profile);

    try {
      final prefs = await _getPrefs();
      await prefs.setString(_profileKey(profile.id), jsonEncode(profile.toJson()));
    } catch (_) {}
  }
}
