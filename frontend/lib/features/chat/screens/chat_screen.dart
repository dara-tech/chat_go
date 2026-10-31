import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/notifications/notification_alert_service.dart';
import '../../../core/services/media_download_service.dart';
import '../../../core/storage/local_chat_storage.dart';
import '../../../core/voice/voice_file_helper.dart';
import '../../../core/voice/voice_service.dart';
import '../../../core/websocket/chat_socket_service.dart';
import '../../../models/chat_message.dart';
import '../../../models/user_model.dart';
import '../../../core/theme/theme_controller.dart';
import '../../map/domain/map_location.dart';
import '../../map/presentation/map_screen.dart';
import '../../media/screens/media_viewer_screen.dart';
import '../../media/widgets/media_attachment_picker_sheet.dart';
import '../services/media_upload_manager.dart';
import '../../../models/group_model.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_forward_sheet.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_action_menu.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/delete_chat_dialog.dart';
import '../widgets/group_info_sheet.dart';
import '../expressions/expression_models.dart';
import '../expressions/expression_registry.dart';
import '../expressions/widgets/expression_picker_sheet.dart';

class ChatScreen extends StatefulWidget {
  final UserModel currentUser;
  final String title;
  final UserModel? chatUser;
  final ChatGroup? group;

  const ChatScreen({
    super.key,
    required this.currentUser,
    this.title = 'Community Lounge',
    this.chatUser,
    this.group,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _socketSubscription;
  UserModel? _partnerUser;
  ChatGroup? _group;
  bool _isWsConnected = false;
  bool _hasText = false;
  bool _isLoadingHistory = false;
  bool _isUploadingMedia = false;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _isVoiceRecording = false;
  bool _isVoicePreviewing = false;
  VoiceRecordingResult? _previewRecording;
  DateTime? _lastPartnerReadTime;
  bool _isPartnerTyping = false;
  Timer? _partnerTypingTimer;
  bool _isLocalTyping = false;
  Timer? _typingDebounceTimer;
  bool _isSelectionMode = false;
  final Set<int> _selectedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _partnerUser = widget.chatUser;
    _group = widget.group;
    NotificationAlertService.instance.activeChatUserId = widget.chatUser?.id;
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onMessageTextChanged);

    _initWebSocket();
    _loadHistory();
    _fetchPartnerUser();
  }

  void _onScroll() {
    if (!_hasMoreOlder || _isLoadingOlder) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadOlderMessages();
    }
  }

  void _onMessageTextChanged() {
    final text = _messageController.text;
    final has = text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }

    final partnerId = widget.chatUser?.id;
    final isGroup = _group != null;
    if (!isGroup && (partnerId == null || partnerId <= 0)) return;

    if (has) {
      if (!_isLocalTyping) {
        _isLocalTyping = true;
        if (isGroup) {
          ChatSocketService.instance.sendGroupTyping(groupId: _group!.id, isTyping: true);
        } else {
          ChatSocketService.instance.sendTyping(receiverId: partnerId!, isTyping: true);
        }
      }
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
        if (_isLocalTyping) {
          _isLocalTyping = false;
          if (isGroup) {
            ChatSocketService.instance.sendGroupTyping(groupId: _group!.id, isTyping: false);
          } else {
            ChatSocketService.instance.sendTyping(receiverId: partnerId!, isTyping: false);
          }
        }
      });
    } else {
      if (_isLocalTyping) {
        _isLocalTyping = false;
        _typingDebounceTimer?.cancel();
        if (isGroup) {
          ChatSocketService.instance.sendGroupTyping(groupId: _group!.id, isTyping: false);
        } else {
          ChatSocketService.instance.sendTyping(receiverId: partnerId!, isTyping: false);
        }
      }
    }
  }

  Future<void> _fetchPartnerUser() async {
    if (widget.chatUser == null) return;
    try {
      final users = await ApiClient.instance.listUsers(limit: 100);
      final found = users.firstWhere(
        (u) => u.id == widget.chatUser!.id,
        orElse: () => _partnerUser ?? widget.chatUser!,
      );
      if (mounted && (found.avatarUrl != _partnerUser?.avatarUrl || found.displayName != _partnerUser?.displayName)) {
        setState(() {
          _partnerUser = found;
        });
      }
    } catch (_) {}
  }

  void _sortMessagesDesc() {
    final seen = <String>{};
    final seenSignatures = <String>{};
    final unique = <Map<String, dynamic>>[];

    for (final m in _messages) {
      final id = m['id']?.toString() ?? '';
      final isTemp = id.startsWith('temp_') || (int.tryParse(id) != null && int.parse(id) > 1000000000000);
      final isPending = m['is_pending'] == true;

      final sender = m['sender_id']?.toString() ?? '';
      final content = m['content']?.toString() ?? '';
      final mediaType = m['media_type']?.toString() ?? 'text';
      final sig = '$sender|$content|$mediaType';

      // 1. Skip duplicate confirmed server IDs
      if (id.isNotEmpty && !isTemp && seen.contains(id)) {
        continue;
      }

      // 2. Skip duplicate pending/temp messages when a confirmed version exists
      if ((isTemp || isPending) && seenSignatures.contains(sig)) {
        continue;
      }

      if (id.isNotEmpty && !isTemp) {
        seen.add(id);
        seenSignatures.add(sig);
      }
      unique.add(m);
    }
    _messages.clear();
    _messages.addAll(unique);

    _messages.sort((a, b) {
      final tA = a['timestamp'] is DateTime
          ? a['timestamp'] as DateTime
          : DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = b['timestamp'] is DateTime
          ? b['timestamp'] as DateTime
          : DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);

    if (_group != null) {
      final cached = await LocalChatStorage.instance.getCachedGroupMessages(_group!.id);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(cached);
          _sortMessagesDesc();
        });
      }
    } else if (widget.chatUser != null) {
      final cached = await LocalChatStorage.instance.getCachedMessages(widget.chatUser!.id);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(cached);
          _sortMessagesDesc();
        });
      }
    }

    try {
      List<ChatMessage> history = [];
      if (_group != null) {
        history = await ApiClient.instance.getGroupMessages(_group!.id, limit: 50);
      } else if (widget.chatUser != null) {
        history = await ApiClient.instance.getMessages(widget.chatUser!.id, limit: 50);
      }

      if (mounted) {
        if (history.isNotEmpty) {
          _reconcileMessages(history);
        } else {
          _hasMoreOlder = false;
        }
        if (_group != null) {
          ApiClient.instance.markGroupRead(_group!.id);
          ChatSocketService.instance.sendGroupReadReceipt(groupId: _group!.id);
        } else if (widget.chatUser != null) {
          ApiClient.instance.markChatRead(widget.chatUser!.id);
          ChatSocketService.instance.sendReadReceipt(widget.chatUser!.id);
          LocalChatStorage.instance.markConversationAsRead(widget.chatUser!.id);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _reconcileMessages(List<ChatMessage> serverMessages) {
    // 1. Clean out any pending/optimistic messages that are confirmed by the server
    for (final sm in serverMessages) {
      if (sm.senderId == widget.currentUser.id) {
        _messages.removeWhere((m) {
          final id = m['id']?.toString() ?? '';
          final isTemp = id.startsWith('temp_') || (int.tryParse(id) != null && int.parse(id) > 1000000000000);
          final isPending = m['is_pending'] == true;
          return (isTemp || isPending) && m['content']?.toString() == sm.content;
        });
      }
    }

    // 2. Add or update server messages
    final existingIds = <String>{};
    for (final m in _messages) {
      final id = m['id']?.toString();
      if (id != null && id.isNotEmpty) existingIds.add(id);
    }

    final newEntries = <Map<String, dynamic>>[];
    for (final sm in serverMessages) {
      if (!existingIds.contains(sm.id.toString())) {
        newEntries.add(sm.toJson());
      } else {
        final idx = _messages.indexWhere((m) => m['id']?.toString() == sm.id.toString());
        if (idx != -1) {
          _messages[idx] = sm.toJson();
        }
      }
    }

    _messages.addAll(newEntries);
    _sortMessagesDesc();

    if (_group != null) {
      LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
    } else if (widget.chatUser != null) {
      LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
    }

    if (serverMessages.length < 50) {
      _hasMoreOlder = false;
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreOlder) return;
    setState(() => _isLoadingOlder = true);

    int? oldestId;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final parsed = int.tryParse(_messages[i]['id']?.toString() ?? '');
      if (parsed != null && parsed < 1000000000000) {
        oldestId = parsed;
        break;
      }
    }

    if (oldestId == null) {
      setState(() {
        _isLoadingOlder = false;
        _hasMoreOlder = false;
      });
      return;
    }

    try {
      List<ChatMessage> older = [];
      if (_group != null) {
        older = await ApiClient.instance.getGroupMessages(
          _group!.id,
          before: oldestId,
          limit: 40,
        );
      } else if (widget.chatUser != null) {
        older = await ApiClient.instance.getMessages(
          widget.chatUser!.id,
          before: oldestId,
          limit: 40,
        );
      }

      if (mounted) {
        if (older.isEmpty) {
          setState(() {
            _hasMoreOlder = false;
            _isLoadingOlder = false;
          });
        } else {
          setState(() {
            for (final msg in older) {
              final exists = _messages.any((m) => m['id']?.toString() == msg.id.toString());
              if (!exists) {
                _messages.add(msg.toJson());
              }
            }
            _sortMessagesDesc();
            if (older.length < 40) {
              _hasMoreOlder = false;
            }
            _isLoadingOlder = false;
          });
          if (_group != null) {
            LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
          } else if (widget.chatUser != null) {
            LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOlder = false);
    }
  }

  void _initWebSocket() {
    final ws = ChatSocketService.instance;
    _isWsConnected = ws.isConnected;
    if (widget.chatUser != null) {
      final isOnline = ws.isUserOnline(widget.chatUser!.id);
      _partnerUser = _partnerUser?.copyWith(isOnline: isOnline);
    }

    _socketSubscription = ws.messageStream.listen((event) {
      if (!mounted) return;

      if (event['type'] == 'connection_status' || event['type'] == 'connection_state_changed') {
        setState(() {
          _isWsConnected = ws.isConnected;
        });
        return;
      }

      if (event['type'] == 'user_status') {
        final rawUserId = event['user_id'];
        final userId = rawUserId is int ? rawUserId : int.tryParse(rawUserId?.toString() ?? '');
        if (widget.chatUser != null && userId == widget.chatUser!.id) {
          final isOnline = event['is_online'] == true;
          setState(() {
            _partnerUser = _partnerUser?.copyWith(isOnline: isOnline);
          });
        }
        return;
      }

      if (event['type'] == 'online_users_snapshot') {
        if (widget.chatUser != null) {
          final isOnline = ws.isUserOnline(widget.chatUser!.id);
          setState(() {
            _partnerUser = _partnerUser?.copyWith(isOnline: isOnline);
          });
        }
        return;
      }

      if (event['type'] == 'chat_message' || event['type'] == 'group_message') {
        final msgSenderId = event['sender_id'];
        final msgReceiverId = event['receiver_id'];
        final msgGroupId = event['group_id'];

        if (_group != null) {
          if (msgGroupId != _group!.id) return;
        } else if (widget.chatUser != null) {
          final isForThisChat = (msgSenderId == widget.chatUser!.id && msgReceiverId == widget.currentUser.id) ||
              (msgSenderId == widget.currentUser.id && msgReceiverId == widget.chatUser!.id);
          if (!isForThisChat) return;
        } else {
          if (msgReceiverId != null && msgReceiverId != 0) return;
          if (msgGroupId != null && msgGroupId != 0) return;
        }

        final incomingId = event['id']?.toString();
        final eventContent = event['content']?.toString() ?? '';
        final eventMediaType = event['media_type']?.toString() ?? 'text';

        // 1. If already exists by server ID, update in-place without resetting is_read
        final existingIdx = _messages.indexWhere((m) => m['id']?.toString() == incomingId);
        if (existingIdx != -1) {
          final wasRead = _messages[existingIdx]['is_read'] == true;
          setState(() {
            _messages[existingIdx] = Map<String, dynamic>.from(event);
            _messages[existingIdx]['is_pending'] = false;
            if (wasRead) {
              _messages[existingIdx]['is_read'] = true;
            }
          });
          return;
        }

        // 2. If sent by current user, reconcile with matching optimistic pending message
        if (msgSenderId?.toString() == widget.currentUser.id.toString()) {
          final pendingIdx = _messages.indexWhere((m) {
            final isPending = m['is_pending'] == true ||
                m['id']?.toString().startsWith('temp_') == true ||
                (int.tryParse(m['id']?.toString() ?? '') != null && int.parse(m['id'].toString()) > 1000000000000);
            final isSameSender = m['sender_id']?.toString() == msgSenderId.toString();
            final isSameContent = m['content']?.toString() == eventContent;
            final isSameMedia = (m['media_type']?.toString() ?? 'text') == eventMediaType;
            return isPending && isSameSender && isSameContent && isSameMedia;
          });

          if (pendingIdx != -1) {
            final wasRead = _messages[pendingIdx]['is_read'] == true;
            setState(() {
              _messages[pendingIdx] = Map<String, dynamic>.from(event);
              _messages[pendingIdx]['is_pending'] = false;
              if (wasRead) {
                _messages[pendingIdx]['is_read'] = true;
              }
              _sortMessagesDesc();
            });
            if (_group != null) {
              LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
            } else if (widget.chatUser != null) {
              LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
            }
            return;
          }
        }

        // 3. New message from partner or other member
        final isFromPartner = widget.chatUser != null && msgSenderId?.toString() == widget.chatUser!.id.toString();
        final newMsg = Map<String, dynamic>.from(event);
        final incomingMsgId = int.tryParse(event['id']?.toString() ?? '');
        if (isFromPartner) {
          _partnerTypingTimer?.cancel();
          _isPartnerTyping = false;
          newMsg['is_read'] = true;
          ApiClient.instance.markChatRead(widget.chatUser!.id);
          ChatSocketService.instance.sendReadReceipt(widget.chatUser!.id, messageId: incomingMsgId);
          LocalChatStorage.instance.markConversationAsRead(widget.chatUser!.id);
        } else if (_group != null && msgSenderId?.toString() != widget.currentUser.id.toString()) {
          _partnerTypingTimer?.cancel();
          _isPartnerTyping = false;
          ApiClient.instance.markGroupRead(_group!.id);
          ChatSocketService.instance.sendGroupReadReceipt(groupId: _group!.id);
        }

        setState(() {
          _messages.insert(0, newMsg);
          _sortMessagesDesc();
        });

        if (_group != null) {
          LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
        } else if (widget.chatUser != null) {
          LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
        }
        _scrollToBottom();
      } else if (event['type'] == 'typing' || event['type'] == 'group_typing') {
        final rawSenderId = event['sender_id'];
        final senderId = rawSenderId is int
            ? rawSenderId
            : int.tryParse(rawSenderId?.toString() ?? '');

        bool shouldShow = false;
        if (_group != null) {
          shouldShow = event['group_id'] == _group!.id && senderId != widget.currentUser.id;
        } else if (widget.chatUser != null && senderId == widget.chatUser!.id) {
          shouldShow = true;
        }

        if (shouldShow) {
          final isTyping = event['is_typing'] == true;
          _partnerTypingTimer?.cancel();
          setState(() {
            _isPartnerTyping = isTyping;
          });
          if (isTyping) {
            _partnerTypingTimer = Timer(const Duration(milliseconds: 3500), () {
              if (mounted) {
                setState(() => _isPartnerTyping = false);
              }
            });
          }
        }
      } else if (event['type'] == 'message_reaction') {
        final targetId = event['message_id'] ?? event['id'] ?? event['payload']?['message_id'];
        final reactions = event['reactions']?.toString() ?? event['payload']?['reactions']?.toString();
        if (targetId != null && reactions != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m['id']?.toString() == targetId.toString());
            if (idx != -1) {
              _messages[idx]['reactions'] = reactions;
            }
          });
          if (widget.chatUser != null) {
            LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
            LocalChatStorage.instance.updateMessageReaction(
              messageId: targetId.toString(),
              reactions: reactions,
              partnerId: widget.chatUser!.id,
            );
          } else if (_group != null) {
            LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
          }
        }
      } else if (event['type'] == 'message_deleted') {
        final targetId = event['message_id'] ?? event['id'] ?? event['payload']?['message_id'];
        if (targetId != null) {
          setState(() {
            _messages.removeWhere((m) => m['id']?.toString() == targetId.toString());
          });
          if (widget.chatUser != null) {
            LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
          } else if (_group != null) {
            LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
          }
        }
      } else if (event['type'] == 'conversation_deleted') {
        final partnerId = event['sender_id'] ?? event['payload']?['partner_id'];
        if (widget.chatUser != null && partnerId?.toString() == widget.chatUser!.id.toString()) {
          setState(() {
            _messages.clear();
          });
          LocalChatStorage.instance.clearChat(widget.chatUser!.id);
        }
      } else if (event['type'] == 'read_receipt' || event['type'] == 'messages_read') {
        final rawReaderId = event['reader_id'] ?? event['sender_id'];
        final readerId = rawReaderId is int
            ? rawReaderId
            : int.tryParse(rawReaderId?.toString() ?? '');
        if (widget.chatUser != null && readerId == widget.chatUser!.id) {
          _lastPartnerReadTime = DateTime.now();
          setState(() {
            for (final m in _messages) {
              if (m['sender_id']?.toString() == widget.currentUser.id.toString()) {
                m['is_read'] = true;
              }
            }
          });
          LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
          LocalChatStorage.instance.updateFromReadReceipt(
            readerId: widget.chatUser!.id,
            currentUserId: widget.currentUser.id,
          );
        }
      } else if (event['type'] == 'group_read') {
        final incomingGroupId = event['group_id'] is int
            ? event['group_id'] as int
            : int.tryParse(event['group_id']?.toString() ?? '');
        if (_group != null && incomingGroupId == _group!.id) {
          final rawReaderId = event['reader_id'] ?? event['sender_id'] ?? event['payload']?['reader_id'];
          final readerId = rawReaderId is int
              ? rawReaderId
              : int.tryParse(rawReaderId?.toString() ?? '');
          final rawMaxMsgId = event['max_message_id'] ?? event['message_id'] ?? event['payload']?['max_message_id'];
          final maxMsgId = rawMaxMsgId is int
              ? rawMaxMsgId
              : int.tryParse(rawMaxMsgId?.toString() ?? '') ?? 0;
          final readerUsername = event['username']?.toString() ?? event['payload']?['username']?.toString() ?? '';
          final readerDisplayName = event['display_name']?.toString() ?? event['payload']?['display_name']?.toString() ?? readerUsername;
          final readerAvatar = event['avatar_url']?.toString() ?? event['payload']?['avatar_url']?.toString() ?? '';

          if (readerId != null && readerId != widget.currentUser.id) {
            setState(() {
              for (final m in _messages) {
                final mId = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '') ?? 0;
                if (mId > 0 && (maxMsgId == 0 || mId <= maxMsgId)) {
                  m['is_read'] = true;
                  final rawSeenBy = m['seen_by'];
                  List<Map<String, dynamic>> seenByList = [];
                  if (rawSeenBy is List) {
                    seenByList = rawSeenBy.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                  }
                  final alreadyExists = seenByList.any((u) => u['user_id'] == readerId);
                  if (!alreadyExists) {
                    seenByList.add({
                      'user_id': readerId,
                      'username': readerUsername,
                      'display_name': readerDisplayName,
                      'avatar_url': readerAvatar,
                    });
                    m['seen_by'] = seenByList;
                    m['seen_count'] = seenByList.length;
                  }
                }
              }
            });
            LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
          }
        }
      }
    });

    if (_group != null) {
      ApiClient.instance.markGroupRead(_group!.id);
      ChatSocketService.instance.sendGroupReadReceipt(groupId: _group!.id);
    } else if (widget.chatUser != null) {
      ApiClient.instance.markChatRead(widget.chatUser!.id);
      ChatSocketService.instance.sendReadReceipt(widget.chatUser!.id);
      LocalChatStorage.instance.markConversationAsRead(widget.chatUser!.id);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuad,
      );
    }
  }

  @override
  void dispose() {
    if (NotificationAlertService.instance.activeChatUserId == widget.chatUser?.id) {
      NotificationAlertService.instance.activeChatUserId = null;
    }
    _socketSubscription?.cancel();
    _typingDebounceTimer?.cancel();
    _partnerTypingTimer?.cancel();
    if (_isLocalTyping && widget.chatUser != null) {
      ChatSocketService.instance.sendTyping(receiverId: widget.chatUser!.id, isTyping: false);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _insertOrUpdateAuthoritativeMessage(
    ChatMessage sent, {
    String? clientToken,
    String? contentMatch,
    Map<String, dynamic>? extraFields,
  }) {
    bool wasRead = false;
    final existingIdx = _messages.indexWhere((m) {
      if (m['id']?.toString() == sent.id.toString()) return true;
      if (clientToken != null && (m['id'] == clientToken || m['client_token'] == clientToken)) return true;
      if (contentMatch != null && m['is_pending'] == true && m['content'] == contentMatch) return true;
      return false;
    });

    Map<String, dynamic>? existingMsg;
    if (existingIdx != -1) {
      existingMsg = Map<String, dynamic>.from(_messages[existingIdx]);
      wasRead = existingMsg['is_read'] == true;
    }

    if (!wasRead && _lastPartnerReadTime != null) {
      final diff = DateTime.now().difference(_lastPartnerReadTime!);
      if (diff.inSeconds <= 5) {
        wasRead = true;
      }
    }

    _messages.removeWhere((m) {
      if (m['id']?.toString() == sent.id.toString()) return true;
      if (clientToken != null && (m['id'] == clientToken || m['client_token'] == clientToken)) return true;
      if (contentMatch != null && m['is_pending'] == true && m['content'] == contentMatch) return true;
      return false;
    });

    final msgJson = sent.toJson();
    if (existingMsg != null) {
      final oldAtts = (existingMsg['attachments'] as List?) ?? [];
      final newAtts = (msgJson['attachments'] as List?) ?? [];
      for (int i = 0; i < newAtts.length && i < oldAtts.length; i++) {
        if (oldAtts[i] is Map && newAtts[i] is Map) {
          if (oldAtts[i]['local_bytes'] != null) {
            newAtts[i]['local_bytes'] = oldAtts[i]['local_bytes'];
          }
          if (oldAtts[i]['local_path'] != null) {
            newAtts[i]['local_path'] = oldAtts[i]['local_path'];
          }
        }
      }
    }
    if (extraFields != null) {
      msgJson.addAll(extraFields);
    }
    if (wasRead) {
      msgJson['is_read'] = true;
    }

    _messages.insert(0, msgJson);
    _sortMessagesDesc();

    if (_group != null) {
      LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
    } else if (widget.chatUser != null) {
      LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
    }
  }

  Future<ChatMessage> _dispatchSendMessage({
    required String content,
    String? clientMessageId,
    String? status,
    String mediaType = 'text',
    String? mediaUrl,
    int? durationMs,
    String? waveform,
    String? forwardFrom,
    List<Map<String, dynamic>>? attachments,
  }) async {
    if (_group != null) {
      return ApiClient.instance.sendGroupMessage(
        _group!.id,
        content: content,
        clientMessageId: clientMessageId,
        status: status,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        durationMs: durationMs,
        waveform: waveform,
        forwardFrom: forwardFrom,
        attachments: attachments,
      );
    } else {
      return ApiClient.instance.sendChatMessage(
        receiverId: widget.chatUser?.id ?? 0,
        content: content,
        clientMessageId: clientMessageId,
        status: status,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        durationMs: durationMs,
        waveform: waveform,
        forwardFrom: forwardFrom,
        attachments: attachments,
      );
    }
  }

  Future<void> _openGroupInfo() async {
    if (_group == null) return;
    final leftGroup = await GroupInfoSheet.show(
      context: context,
      initialGroup: _group!,
      currentUser: widget.currentUser,
      onGroupUpdated: (updated) {
        if (mounted) setState(() => _group = updated);
      },
    );
    if (leftGroup == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_isLocalTyping) {
      _isLocalTyping = false;
      _typingDebounceTimer?.cancel();
      if (_group != null) {
        ChatSocketService.instance.sendGroupTyping(groupId: _group!.id, isTyping: false);
      } else if (widget.chatUser != null) {
        ChatSocketService.instance.sendTyping(receiverId: widget.chatUser!.id, isTyping: false);
      }
    }

    _messageController.clear();
    setState(() => _hasText = false);

    final clientToken = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final tempMsg = {
      'id': clientToken,
      'client_token': clientToken,
      'sender_id': widget.currentUser.id,
      'receiver_id': widget.chatUser?.id,
      'group_id': _group?.id,
      'username': widget.currentUser.username,
      'content': text,
      'media_type': 'text',
      'media_url': null,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
      'is_pending': true,
    };

    setState(() {
      _messages.insert(0, tempMsg);
      _sortMessagesDesc();
    });
    _scrollToBottom();

    try {
      final sent = await _dispatchSendMessage(
        content: text,
        mediaType: 'text',
      );

      if (mounted) {
        setState(() {
          _insertOrUpdateAuthoritativeMessage(
            sent,
            clientToken: clientToken,
            contentMatch: text,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == clientToken || m['client_token'] == clientToken);
          if (idx != -1) {
            _messages[idx]['is_failed'] = true;
            _messages[idx]['is_pending'] = false;
          }
        });
      }
    }
  }

  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => MediaAttachmentPickerSheet(
        currentUser: widget.currentUser,
        onPickCamera: () { Navigator.of(ctx).pop(); _pickAndSendImage(ImageSource.camera); },
        onPickGallery: () { Navigator.of(ctx).pop(); _pickAndSendImage(ImageSource.gallery); },
        onPickFile: () { Navigator.of(ctx).pop(); _pickAndSendFile(); },
        onSendLocation: (t, a) { _sendLocationMessage(t, a); },
        onSendPhotoBytes: (b, n) { Navigator.of(ctx).pop(); _sendPhotoBytes(b, n); },
        onSendMultiMedia: (items, caption) {
          _sendMultiMedia(items, caption);
        },
      ),
    );
  }

  void _showExpressionPicker() {
    ExpressionPickerSheet.show(
      context,
      onSelectEmoji: (emojiText) {
        _sendEmojiMessage(emojiText);
        _messageController.clear();
        setState(() => _hasText = false);
      },
      onSelectAnimatedEmoji: (animatedEmoji) {
        _sendAnimatedEmoji(animatedEmoji);
      },
      onSelectSticker: (sticker) {
        _sendSticker(sticker);
      },
      onSelectReaction: (reaction) {
        if (_messages.isNotEmpty) {
          final lastMsg = _messages.first;
          _toggleReaction(lastMsg, reaction.unicodeFallback);
        }
      },
    );
  }

  Future<void> _sendEmojiMessage(String emojiText) async {
    for (final anim in ExpressionRegistry.animatedEmojis) {
      if (anim.unicodeFallback == emojiText) {
        return _sendAnimatedEmoji(anim);
      }
    }

    final codepoint = emojiText.runes.map((r) => r.toRadixString(16)).join('_');
    final animItem = AnimatedEmojiItem(
      id: 'custom_emoji_$codepoint',
      name: 'Emoji',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/$codepoint/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/$codepoint/512.webp',
      unicodeFallback: emojiText,
    );
    return _sendAnimatedEmoji(animItem);
  }

  Future<void> _sendSticker(AnimatedStickerItem sticker) async {
    final clientToken = 'sticker_${DateTime.now().microsecondsSinceEpoch}';
    final tempMsg = {
      'id': clientToken,
      'client_token': clientToken,
      'sender_id': widget.currentUser.id,
      'receiver_id': widget.chatUser?.id,
      'group_id': _group?.id,
      'username': widget.currentUser.username,
      'content': sticker.name,
      'media_type': 'sticker',
      'media_url': sticker.webpUrl,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
      'is_pending': true,
    };

    _messageController.clear();
    setState(() {
      _hasText = false;
      _messages.insert(0, tempMsg);
      _sortMessagesDesc();
    });
    _scrollToBottom();

    try {
      final sent = await _dispatchSendMessage(
        content: sticker.name,
        mediaType: 'sticker',
        mediaUrl: sticker.webpUrl,
      );

      if (mounted) {
        setState(() {
          _insertOrUpdateAuthoritativeMessage(
            sent,
            clientToken: clientToken,
            contentMatch: sticker.name,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == clientToken || m['client_token'] == clientToken);
          if (idx != -1) {
            _messages[idx]['is_failed'] = true;
            _messages[idx]['is_pending'] = false;
          }
        });
      }
    }
  }

  Future<void> _sendAnimatedEmoji(AnimatedEmojiItem item) async {
    final clientToken = 'anim_emoji_${DateTime.now().microsecondsSinceEpoch}';
    final tempMsg = {
      'id': clientToken,
      'client_token': clientToken,
      'sender_id': widget.currentUser.id,
      'receiver_id': widget.chatUser?.id,
      'group_id': _group?.id,
      'username': widget.currentUser.username,
      'content': item.unicodeFallback,
      'media_type': 'animated_emoji',
      'media_url': item.lottieUrl,
      'media_url_webp': item.animatedWebpUrl,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
      'is_pending': true,
    };

    _messageController.clear();
    setState(() {
      _hasText = false;
      _messages.insert(0, tempMsg);
      _sortMessagesDesc();
    });
    _scrollToBottom();

    try {
      final sent = await _dispatchSendMessage(
        content: item.unicodeFallback,
        mediaType: 'animated_emoji',
        mediaUrl: item.lottieUrl,
      );

      if (mounted) {
        setState(() {
          _insertOrUpdateAuthoritativeMessage(
            sent,
            clientToken: clientToken,
            contentMatch: item.unicodeFallback,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == clientToken || m['client_token'] == clientToken);
          if (idx != -1) {
            _messages[idx]['is_failed'] = true;
            _messages[idx]['is_pending'] = false;
          }
        });
      }
    }
  }

  Future<void> _sendMultiMedia(List<LocalMediaAttachment> items, String caption) async {
    if (items.isEmpty) return;

    final clientToken = 'client_multi_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final isAlbum = items.length > 1 && items.every((i) => i.isImage || i.isVideo);
    final isMultiDoc = items.length > 1 && items.any((i) => i.isDocument);
    final mediaType = items.length > 1
        ? (isAlbum ? 'album' : (isMultiDoc ? 'mixed' : 'mixed'))
        : items.first.mediaType;

    // Step 2 & 3: Prepare manifest & immediately display pending message in timeline
    final pendingAttachments = items.map((i) => i.toMessageAttachment().toJson()).toList();
    final pendingMsg = {
      'id': clientToken,
      'client_message_id': clientToken,
      'client_token': clientToken,
      'sender_id': widget.currentUser.id,
      'receiver_id': widget.chatUser?.id ?? 0,
      'group_id': _group?.id,
      'username': widget.currentUser.username,
      'sender_avatar': widget.currentUser.avatarUrl,
      'content': caption,
      'status': 'uploading',
      'media_type': mediaType,
      'media_url': '',
      'attachments': pendingAttachments,
      'is_pending': true,
      'is_failed': false,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.insert(0, pendingMsg);
    });
    _scrollToBottom();

    // Step 4: Upload attachments with bounded concurrency (e.g. 2 or 3 parallel workers)
    final uploadManager = MediaUploadManager.instance;
    await uploadManager.uploadAttachments(
      attachments: items,
      maxConcurrency: 3,
      onProgress: (item, overallProgress) {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m['client_token'] == clientToken || m['id'] == clientToken);
          if (idx != -1) {
            final atts = (_messages[idx]['attachments'] as List?) ?? [];
            for (int i = 0; i < atts.length; i++) {
              if (atts[i]['sort_order'] == item.sortOrder) {
                atts[i]['progress'] = item.progress;
                atts[i]['upload_status'] = item.uploadStatus;
                atts[i]['url'] = item.remoteUrl ?? '';
              }
            }
          }
        });
      },
      onItemComplete: (item) {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m['client_token'] == clientToken || m['id'] == clientToken);
          if (idx != -1) {
            final atts = (_messages[idx]['attachments'] as List?) ?? [];
            for (int i = 0; i < atts.length; i++) {
              if (atts[i]['sort_order'] == item.sortOrder) {
                atts[i]['upload_status'] = 'completed';
                atts[i]['url'] = item.remoteUrl ?? '';
                atts[i]['progress'] = 1.0;
              }
            }
          }
        });
      },
      onItemFailed: (item, error) {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m['client_token'] == clientToken || m['id'] == clientToken);
          if (idx != -1) {
            final atts = (_messages[idx]['attachments'] as List?) ?? [];
            for (int i = 0; i < atts.length; i++) {
              if (atts[i]['sort_order'] == item.sortOrder) {
                atts[i]['upload_status'] = 'failed';
              }
            }
            _messages[idx]['is_failed'] = true;
          }
        });
      },
    );

    // Step 5: Finalize and deliver if all attachments uploaded
    final hasFailed = items.any((i) => !i.isCompleted);
    if (hasFailed) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['client_token'] == clientToken || m['id'] == clientToken);
          if (idx != -1) {
            _messages[idx]['is_failed'] = true;
          }
        });
      }
      return;
    }

    try {
      final serverAttachments = items.map((i) => i.toServerPayload()).toList();
      final safeContent = caption.trim().isNotEmpty
          ? caption.trim()
          : (items.length == 1
              ? items.first.fileName
              : (mediaType == 'album' ? 'Album' : (mediaType == 'image' ? 'Photo' : 'Media')));

      final sent = await _dispatchSendMessage(
        clientMessageId: clientToken,
        content: safeContent,
        status: 'sent',
        mediaType: mediaType,
        mediaUrl: items.isNotEmpty ? items.first.remoteUrl : null,
        attachments: serverAttachments,
      );

      if (mounted) {
        setState(() {
          _insertOrUpdateAuthoritativeMessage(
            sent,
            clientToken: clientToken,
            contentMatch: caption,
          );
        });
        _scrollToBottom();
      }
    } catch (e, stack) {
      debugPrint('Error in _sendMultiMedia: $e\n$stack');
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['client_token'] == clientToken || m['id'] == clientToken);
          if (idx != -1) {
            _messages[idx]['is_failed'] = true;
          }
        });
      }
    }
  }

  Future<void> _retryAttachment(Map<String, dynamic> msg, int attachmentIndex) async {
    final clientToken = (msg['client_message_id'] ?? msg['client_token'] ?? msg['id']).toString();
    final rawAtts = msg['attachments'] as List?;
    if (rawAtts == null || attachmentIndex >= rawAtts.length) return;

    final targetMap = rawAtts[attachmentIndex] as Map<String, dynamic>;
    final item = LocalMediaAttachment(
      id: '${clientToken}_$attachmentIndex',
      mediaType: targetMap['media_type'] ?? 'file',
      mimeType: targetMap['mime_type'] ?? '',
      fileName: targetMap['file_name'] ?? 'file',
      sizeBytes: (targetMap['size_bytes'] as num?)?.toInt() ?? 0,
      localPath: targetMap['local_path']?.toString(),
      bytes: targetMap['local_bytes'] as Uint8List?,
      remoteUrl: targetMap['url']?.toString(),
      uploadStatus: 'pending',
      sortOrder: (targetMap['sort_order'] as num?)?.toInt() ?? attachmentIndex,
    );

    setState(() {
      targetMap['upload_status'] = 'uploading';
      targetMap['progress'] = 0.1;
      msg['is_failed'] = false;
    });

    await MediaUploadManager.instance.uploadAttachments(
      attachments: [item],
      onProgress: (i, p) {
        if (!mounted) return;
        setState(() {
          targetMap['progress'] = i.progress;
          targetMap['upload_status'] = i.uploadStatus;
        });
      },
      onItemComplete: (i) {
        if (!mounted) return;
        setState(() {
          targetMap['upload_status'] = 'completed';
          targetMap['url'] = i.remoteUrl ?? '';
          targetMap['progress'] = 1.0;
        });
      },
      onItemFailed: (i, err) {
        if (!mounted) return;
        setState(() {
          targetMap['upload_status'] = 'failed';
          msg['is_failed'] = true;
        });
      },
    );

    // If all attachments are now completed, finalize message on backend
    final allCompleted = rawAtts.every((a) => (a['upload_status'] ?? '') == 'completed');
    if (allCompleted) {
      try {
        final serverPayloads = rawAtts.map((a) {
          return {
            'media_type': a['media_type'] ?? 'file',
            'mime_type': a['mime_type'] ?? '',
            'file_name': a['file_name'] ?? '',
            'size_bytes': a['size_bytes'] ?? 0,
            'url': a['url'] ?? '',
            'upload_status': 'completed',
            'sort_order': a['sort_order'] ?? 0,
          };
        }).toList();

        final sent = await _dispatchSendMessage(
          clientMessageId: clientToken,
          content: msg['content']?.toString() ?? '',
          status: 'sent',
          mediaType: msg['media_type']?.toString() ?? 'mixed',
          mediaUrl: rawAtts.isNotEmpty ? rawAtts.first['url']?.toString() : null,
          attachments: serverPayloads,
        );

        if (mounted) {
          setState(() {
            _insertOrUpdateAuthoritativeMessage(
              sent,
              clientToken: clientToken,
            );
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _sendPhotoBytes(List<int> bytes, String filename) async {
    setState(() => _isUploadingMedia = true);
    try {
      final url = await ApiClient.instance.uploadChatMedia(
        bytes: bytes,
        filename: filename,
      );
      final sent = await _dispatchSendMessage(
        content: 'Photo',
        mediaType: 'image',
        mediaUrl: url,
      );

      if (mounted) {
        setState(() {
          _insertOrUpdateAuthoritativeMessage(
            sent,
            contentMatch: 'Photo',
          );
        });
        _scrollToBottom();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _sendPhotoBytes(bytes, picked.name);
  }

  Future<void> _pickAndSendFile() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final items = <LocalMediaAttachment>[];
    for (int i = 0; i < files.length; i++) {
      final f = files[i];
      final mType = MediaUploadManager.guessMediaType(f.name);
      final mime = MediaUploadManager.guessMimeType(f.name);
      Uint8List? bytes;
      int size = 0;
      if (f.path != null && !kIsWeb) {
        try {
          final ioFile = File(f.path!);
          if (ioFile.existsSync()) {
            size = ioFile.lengthSync();
            // For smaller files, read into bytes; for large files, leave as null to stream from disk!
            if (size < 5 * 1024 * 1024) {
              bytes = await ioFile.readAsBytes();
            }
          }
        } catch (_) {}
      } else {
        try {
          bytes = await f.readAsBytes();
          size = bytes.length;
        } catch (_) {}
      }
      items.add(LocalMediaAttachment(
        id: 'file_${DateTime.now().millisecondsSinceEpoch}_$i',
        mediaType: mType,
        mimeType: mime,
        fileName: f.name,
        sizeBytes: size,
        localPath: f.path,
        bytes: bytes,
        sortOrder: i,
      ));
    }
    await _sendMultiMedia(items, '');
  }

  Future<void> _sendLocationMessage(String title, String address) async {
    final cleanTitle = title.trim();
    final cleanAddress = address.trim();
    final locPayload = cleanAddress.contains('geo:')
        ? (cleanTitle.startsWith('📍') ? '$cleanTitle\n$cleanAddress' : '📍 $cleanTitle\n$cleanAddress')
        : (cleanTitle.startsWith('📍') ? '$cleanTitle\n$cleanAddress' : '📍 $cleanTitle\n$cleanAddress');
    try {
      final sent = await _dispatchSendMessage(
        content: locPayload,
        mediaType: 'location',
      );
      if (mounted) {
        setState(() {
          _insertOrUpdateAuthoritativeMessage(
            sent,
            contentMatch: locPayload,
          );
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _openLocationDetails(String rawContent, [Map<String, dynamic>? msg]) {
    final loc = MapLocation.parseContent(rawContent);

    final isMe = msg != null && ((msg['sender_id'] == widget.currentUser.id) || (msg['is_me'] == true));
    final senderName = msg != null
        ? (isMe
            ? widget.currentUser.displayName
            : ((msg['sender_name'] as String?) ??
                (msg['username'] as String?) ??
                _partnerUser?.displayName ??
                widget.title))
        : (_partnerUser?.displayName ?? widget.title);

    final senderAvatar = msg != null
        ? (isMe
            ? widget.currentUser.avatarUrl
            : ((msg['sender_avatar'] as String?)?.trim() ?? _partnerUser?.avatarUrl ?? ''))
        : (_partnerUser?.avatarUrl ?? '');

    final senderUsername = msg != null
        ? (isMe
            ? widget.currentUser.username
            : ((msg['username'] as String?) ?? _partnerUser?.username ?? ''))
        : (_partnerUser?.username ?? '');

    final sharedAt = msg != null && msg['timestamp'] != null
        ? DateTime.tryParse(msg['timestamp'].toString())
        : null;

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MapScreen(
          initialLocation: loc,
          currentUser: widget.currentUser,
          partnerUser: _partnerUser ?? widget.chatUser,
          partnerName: _partnerUser?.displayName ?? widget.title,
          senderName: senderName,
          senderAvatarUrl: senderAvatar,
          senderUsername: senderUsername,
          sharedAt: sharedAt,
        ),
      ),
    );
  }

  void _openImagePreview(String imageUrl) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MediaViewerScreen(
          items: [
            MediaViewerItem(
              id: imageUrl,
              mediaUrl: ApiClient.resolveAvatarUrl(imageUrl),
              senderName: _partnerUser?.displayName ?? widget.title,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      ),
    );
  }

  void _openAlbumPreview(List<String> imageUrls, int initialIndex) {
    if (imageUrls.isEmpty) return;
    final items = imageUrls.map((url) {
      final resolved = ApiClient.resolveAvatarUrl(url);
      return MediaViewerItem(
        id: url,
        mediaUrl: resolved,
        senderName: _partnerUser?.displayName ?? widget.title,
        timestamp: DateTime.now(),
      );
    }).toList();

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MediaViewerScreen(
          items: items,
          initialIndex: initialIndex.clamp(0, items.length - 1),
        ),
      ),
    );
  }

  void _openMediaUrl(String url, String filename) {
    final lower = filename.toLowerCase();
    final isImg = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
    if (isImg) {
      _openImagePreview(url);
      return;
    }
    MediaDownloadService.instance.openMedia(context, url: url, filename: filename);
  }

  Future<void> _startVoiceRecording() async {
    if (await VoiceService.instance.startRecording() && mounted) {
      setState(() {
        _isVoiceRecording = true;
        _isVoicePreviewing = false;
        _previewRecording = null;
      });
    }
  }

  Future<void> _cancelVoiceRecording() async {
    await VoiceService.instance.cancelRecording();
    if (mounted) {
      setState(() {
        _isVoiceRecording = false;
        _isVoicePreviewing = false;
        _previewRecording = null;
      });
    }
  }

  Future<void> _lockOrPreviewVoiceRecording() async {
    final res = await VoiceService.instance.stopRecording();
    if (res != null && mounted) {
      setState(() {
        _isVoiceRecording = false;
        _isVoicePreviewing = true;
        _previewRecording = res;
      });
    }
  }

  Future<void> _sendVoiceRecording() async {
    final res = _isVoiceRecording ? await VoiceService.instance.stopRecording() : _previewRecording;
    if (res == null) return;
    setState(() {
      _isVoiceRecording = false;
      _isVoicePreviewing = false;
      _previewRecording = null;
    });
    await _uploadAndSendVoiceMessage(res);
  }

  Future<void> _uploadAndSendVoiceMessage(VoiceRecordingResult recording) async {
    final clientToken = 'temp_voice_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': clientToken,
      'client_token': clientToken,
      'sender_id': widget.currentUser.id,
      'receiver_id': widget.chatUser?.id,
      'group_id': _group?.id,
      'username': widget.currentUser.username,
      'content': 'Voice Message',
      'media_type': 'voice',
      'media_url': recording.path,
      'duration_ms': recording.durationMs,
      'waveform': jsonEncode(recording.waveform),
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
      'is_pending': true,
    };

    setState(() {
      _isUploadingMedia = true;
      _messages.insert(0, tempMsg);
      _sortMessagesDesc();
    });
    _scrollToBottom();

    try {
      Uint8List bytes = recording.bytes;
      if (bytes.isEmpty) {
        bytes = await VoiceFileHelper.readFileBytes(recording.path);
      }
      if (bytes.isEmpty) {
        throw Exception('Audio recording data is empty');
      }

      final ext = VoiceFileHelper.getVoiceFileExtension();
      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}$ext';

      final url = await ApiClient.instance.uploadChatMedia(
        bytes: bytes,
        filename: filename,
      );

      final sent = await _dispatchSendMessage(
        content: 'Voice Message',
        mediaType: 'voice',
        mediaUrl: url,
        durationMs: recording.durationMs,
        waveform: jsonEncode(recording.waveform),
      );

      if (mounted) {
        setState(() {
          _insertOrUpdateAuthoritativeMessage(
            sent,
            clientToken: clientToken,
            contentMatch: 'Voice Message',
            extraFields: {
              'duration_ms': recording.durationMs,
              'waveform': jsonEncode(recording.waveform),
              'media_url': url,
            },
          );
        });
      }
    } catch (e, st) {
      debugPrint('[ChatScreen] Error uploading/sending voice message: $e\n$st');
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == clientToken || m['client_token'] == clientToken);
          if (idx != -1) {
            _messages[idx]['is_failed'] = true;
            _messages[idx]['is_pending'] = false;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _toggleReaction(Map<String, dynamic> msg, String emoji) async {
    final msgId = msg['id'] is int ? msg['id'] as int : int.tryParse(msg['id']?.toString() ?? '');
    if (msgId == null) return;
    try {
      final updatedReactions = await ApiClient.instance.reactToMessage(msgId, emoji);
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id']?.toString() == msgId.toString());
          if (idx != -1) {
            _messages[idx]['reactions'] = updatedReactions;
          }
        });
        if (widget.chatUser != null) {
          LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
          LocalChatStorage.instance.updateMessageReaction(
            messageId: msgId.toString(),
            reactions: updatedReactions,
            partnerId: widget.chatUser!.id,
          );
        } else if (_group != null) {
          LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
        }
      }
    } catch (_) {}
  }

  void _confirmDeleteMessage(Map<String, dynamic> msg) {
    final senderId = msg['sender_id'];
    final isMe = (senderId == widget.currentUser.id) || (msg['is_me'] == true);

    if (isMe) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Do you want to delete this message for everyone or only for yourself?'),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteMessage(msg, forEveryone: true);
              },
              child: const Text('Delete for Everyone'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteMessage(msg, forEveryone: false);
              },
              child: const Text('Delete for Me'),
            ),
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    } else {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message for yourself? It will remain visible to other participants.'),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteMessage(msg, forEveryone: false);
              },
              child: const Text('Delete for Me'),
            ),
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> msg, {bool forEveryone = false}) async {
    final id = msg['id'] is int ? msg['id'] as int : int.tryParse(msg['id']?.toString() ?? '');
    final clientMsgId = msg['client_message_id']?.toString();

    // Immediately remove from UI and local storage
    if (mounted) {
      setState(() {
        _messages.removeWhere((m) {
          if (id != null && m['id'] != null) {
            return m['id'].toString() == id.toString();
          }
          if (clientMsgId != null && m['client_message_id'] != null) {
            return m['client_message_id'] == clientMsgId;
          }
          return false;
        });
      });
      if (widget.chatUser != null) {
        LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
      } else if (_group != null) {
        LocalChatStorage.instance.saveGroupMessages(_group!.id, _messages);
      }
    }

    if (id != null) {
      try {
        await ApiClient.instance.deleteMessage(id, forEveryone: forEveryone);
      } catch (_) {}
    }
  }

  Future<void> _forwardMessageToUser(Map<String, dynamic> msg, UserModel recipient) async {
    final content = msg['content']?.toString() ?? '';
    final mediaType = msg['media_type']?.toString() ?? 'text';
    final mediaUrl = msg['media_url']?.toString();

    final existingForward = msg['forward_from']?.toString();
    String originAuthor;
    if (existingForward != null && existingForward.trim().isNotEmpty) {
      originAuthor = existingForward.trim();
    } else {
      final senderId = msg['sender_id'];
      if (senderId == widget.currentUser.id) {
        originAuthor = widget.currentUser.displayName.isNotEmpty ? widget.currentUser.displayName : widget.currentUser.username;
      } else if (widget.chatUser != null) {
        originAuthor = widget.chatUser!.displayName.isNotEmpty ? widget.chatUser!.displayName : widget.chatUser!.username;
      } else {
        originAuthor = msg['username']?.toString() ?? 'User';
      }
    }

    try {
      final sent = await ApiClient.instance.sendChatMessage(
        receiverId: recipient.id,
        content: content,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        forwardFrom: originAuthor,
      );

      if (widget.chatUser?.id == recipient.id && mounted) {
        setState(() {
          _insertOrUpdateAuthoritativeMessage(
            sent,
            contentMatch: content,
          );
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _handleReply(Map<String, dynamic> msg) {
    final content = msg['content']?.toString() ?? '';
    final sender = msg['username']?.toString() ?? 'User';
    if (content.isNotEmpty) {
      _messageController.text = '> $sender: $content\n';
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }
  }

  void _handleEdit(Map<String, dynamic> msg) {
    final content = msg['content']?.toString() ?? '';
    if (content.isNotEmpty) {
      _messageController.text = content;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }
  }

  void _handlePin(Map<String, dynamic> msg) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message pinned', style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: ThemeController.instance.cardBg,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleSelect(Map<String, dynamic> msg) {
    final id = msg['id'] is int ? msg['id'] as int : int.tryParse(msg['id']?.toString() ?? '') ?? 0;
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      if (id != 0) _selectedMessageIds.add(id);
    });
    HapticFeedback.mediumImpact();
  }

  void _toggleSelectMessage(Map<String, dynamic> msg) {
    final id = msg['id'] is int ? msg['id'] as int : int.tryParse(msg['id']?.toString() ?? '') ?? 0;
    if (id == 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMessageIds.contains(id)) {
        _selectedMessageIds.remove(id);
      } else {
        _selectedMessageIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _confirmClearChat() async {
    HapticFeedback.mediumImpact();
    final partnerName = _partnerUser?.displayName.isNotEmpty == true
        ? _partnerUser!.displayName
        : widget.title;

    final res = await DeleteChatDialog.show(context, partnerName: partnerName);
    if (res != null && mounted) {
      if (widget.chatUser != null) {
        try {
          await ApiClient.instance.deleteConversation(
            widget.chatUser!.id,
            forEveryone: res.deleteForEveryone,
          );
        } catch (_) {}
        await LocalChatStorage.instance.clearChat(widget.chatUser!.id);
      }
      setState(() {
        _messages.clear();
        _exitSelectionMode();
      });
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    HapticFeedback.mediumImpact();

    final ids = List<int>.from(_selectedMessageIds);
    final count = ids.length;

    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Delete $count message${count > 1 ? 's' : ''}?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('everyone'),
            child: const Text('Delete for Everyone'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('me'),
            child: const Text('Delete for Me'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action != null && mounted) {
      final forEveryone = action == 'everyone';
      final msgsToDelete = _messages.where((m) {
        final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '') ?? 0;
        return ids.contains(id);
      }).toList();

      setState(() {
        _messages.removeWhere((m) {
          final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '') ?? 0;
          return ids.contains(id);
        });
        _exitSelectionMode();
      });

      // Call backend delete
      for (final m in msgsToDelete) {
        final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '') ?? 0;
        if (id <= 0) continue;
        final senderId = m['sender_id'];
        final isSender = senderId == widget.currentUser.id || m['username'] == widget.currentUser.username;
        final deleteEveryoneForThis = forEveryone && isSender;
        ApiClient.instance.deleteMessage(id, forEveryone: deleteEveryoneForThis).catchError((_) {});
      }

      if (widget.chatUser != null) {
        LocalChatStorage.instance.saveMessages(widget.chatUser!.id, _messages);
      }
    }
  }

  void _shareSelectedMessages() {
    if (_selectedMessageIds.isEmpty) return;
    HapticFeedback.lightImpact();

    final selectedMsgs = _messages.where((m) {
      final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '') ?? 0;
      return _selectedMessageIds.contains(id);
    }).toList();

    // Sort chronologically (oldest first)
    selectedMsgs.sort((a, b) {
      final tA = a['timestamp'] is DateTime
          ? a['timestamp'] as DateTime
          : DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(0);
      final tB = b['timestamp'] is DateTime
          ? b['timestamp'] as DateTime
          : DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(0);
      return tA.compareTo(tB);
    });

    final buffer = StringBuffer();
    for (final m in selectedMsgs) {
      final sender = m['username'] ?? 'User';
      final content = m['content']?.toString() ?? '';
      final time = ChatMessageBubble.formatTime(m['timestamp']);
      if (content.isNotEmpty) {
        buffer.writeln('[$time] $sender: $content');
      }
    }

    final text = buffer.toString().trim();
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${_selectedMessageIds.length} message(s) to clipboard',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: ThemeController.instance.cardBg,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _exitSelectionMode();
  }

  void _forwardSelectedMessages() {
    if (_selectedMessageIds.isEmpty) return;
    HapticFeedback.lightImpact();

    final selectedMsgs = _messages.where((m) {
      final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '') ?? 0;
      return _selectedMessageIds.contains(id);
    }).toList();

    if (selectedMsgs.isEmpty) return;

    ChatForwardSheet.show(
      context: context,
      msg: selectedMsgs.first,
      currentUser: widget.currentUser,
      onForwardToUser: (recipient) async {
        for (final m in selectedMsgs) {
          await _forwardMessageToUser(m, recipient);
        }
        if (mounted) _exitSelectionMode();
      },
    );
  }

  Widget _buildSelectionTopBar(ThemeController theme) {
    final count = _selectedMessageIds.length;

    return Container(
      height: 48,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Clear Chat text button (no background)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _confirmClearChat,
            child: Text(
              'Clear Chat',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFFF3B30),
              ),
            ),
          ),

          // 2. Count Title (no background)
          Text(
            '$count Selected',
            style: GoogleFonts.inter(
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),

          // 3. Cancel text button (no background)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _exitSelectionMode,
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBottomBar(ThemeController theme) {
    final hasSelection = _selectedMessageIds.isNotEmpty;
    final activeColor = theme.textPrimary;
    final disabledColor = theme.textMuted.withOpacity(0.35);

    return Container(
      height: 52,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Delete
          IconButton(
            icon: Icon(
              CupertinoIcons.trash,
              size: 23,
              color: hasSelection ? const Color(0xFFFF3B30) : disabledColor,
            ),
            onPressed: hasSelection ? _deleteSelectedMessages : null,
          ),

          // Share / Copy
          IconButton(
            icon: Icon(
              CupertinoIcons.square_arrow_up,
              size: 23,
              color: hasSelection ? activeColor : disabledColor,
            ),
            onPressed: hasSelection ? _shareSelectedMessages : null,
          ),

          // Forward
          IconButton(
            icon: Icon(
              CupertinoIcons.arrowshape_turn_up_right,
              size: 23,
              color: hasSelection ? activeColor : disabledColor,
            ),
            onPressed: hasSelection ? _forwardSelectedMessages : null,
          ),
        ],
      ),
    );
  }

  void _onLongPressMessage(Map<String, dynamic> msg) {
    if (_isSelectionMode) return;

    ChatMessageActionMenu.show(
      context: context,
      msg: msg,
      currentUser: widget.currentUser,
      partnerUser: _partnerUser ?? widget.chatUser,
      onReactionSelected: (emoji) => _toggleReaction(msg, emoji),
      onReply: () => _handleReply(msg),
      onEdit: () => _handleEdit(msg),
      onPin: () => _handlePin(msg),
      onForward: () => ChatForwardSheet.show(
        context: context,
        msg: msg,
        currentUser: widget.currentUser,
        onForwardToUser: (recipient) => _forwardMessageToUser(msg, recipient),
      ),
      onDelete: () => _confirmDeleteMessage(msg),
      onSelect: () => _handleSelect(msg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;

        return PopScope(
          canPop: !_isSelectionMode,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _isSelectionMode) {
              _exitSelectionMode();
            }
          },
          child: Scaffold(
            backgroundColor: theme.scaffoldBg,
            body: SafeArea(
              child: Column(
                children: [
                  if (_isSelectionMode)
                    _buildSelectionTopBar(theme)
                  else
                    ChatAppBar(
                      currentUser: widget.currentUser,
                      partnerUser: _partnerUser ?? widget.chatUser,
                      group: _group,
                      title: _group?.name ?? widget.title,
                      isWsConnected: _isWsConnected,
                      canPop: canPop,
                      isPartnerTyping: _isPartnerTyping,
                      onGroupInfoTap: _openGroupInfo,
                    ),
                  if (!_isSelectionMode)
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
                  Expanded(
                    child: _isLoadingHistory && _messages.isEmpty
                        ? const Center(child: CupertinoActivityIndicator(radius: 12))
                        : ChatMessageList(
                            scrollController: _scrollController,
                            messages: _messages,
                            isLoadingOlder: _isLoadingOlder,
                            currentUser: widget.currentUser,
                            partnerUser: _partnerUser ?? widget.chatUser,
                            isDirectChat: widget.chatUser != null && _group == null,
                            isPartnerTyping: _isPartnerTyping,
                            isSelectionMode: _isSelectionMode,
                            selectedMessageIds: _selectedMessageIds,
                            onToggleSelectMessage: _toggleSelectMessage,
                            onOpenImagePreview: _openImagePreview,
                            onOpenMediaUrl: _openMediaUrl,
                            onOpenLocationDetails: _openLocationDetails,
                            onLongPressMessage: _onLongPressMessage,
                            onToggleReaction: _toggleReaction,
                            onOpenAlbumPreview: _openAlbumPreview,
                            onRetryAttachment: _retryAttachment,
                            chatTitle: _group?.name ?? widget.title,
                          ),
                  ),
                  if (_isSelectionMode)
                    _buildSelectionBottomBar(theme)
                  else
                    ChatInputBar(
                      messageController: _messageController,
                      hasText: _hasText,
                      isUploadingMedia: _isUploadingMedia,
                      isVoiceRecording: _isVoiceRecording,
                      isVoicePreviewing: _isVoicePreviewing,
                      previewRecording: _previewRecording,
                      onSendMessage: _sendMessage,
                      onShowAttachmentModal: _showAttachmentModal,
                      onShowExpressionPicker: _showExpressionPicker,
                      onStartVoiceRecording: _startVoiceRecording,
                      onCancelVoiceRecording: _cancelVoiceRecording,
                      onLockOrPreviewVoiceRecording: _lockOrPreviewVoiceRecording,
                      onSendVoiceRecording: _sendVoiceRecording,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
