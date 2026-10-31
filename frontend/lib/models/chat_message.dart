import 'dart:convert';
import 'user_model.dart';

class MessageAttachment {
  final int id;
  final int messageId;
  final String mediaType; // image, video, audio, voice, document
  final String mimeType;
  final String fileName;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? storageKey;
  final String url;
  final String uploadStatus; // pending, uploading, completed, failed
  final int sortOrder;
  final double progress;
  final String? localPath;
  final List<int>? localBytes;

  const MessageAttachment({
    this.id = 0,
    this.messageId = 0,
    required this.mediaType,
    this.mimeType = '',
    required this.fileName,
    this.sizeBytes = 0,
    this.width,
    this.height,
    this.durationMs,
    this.storageKey,
    required this.url,
    this.uploadStatus = 'completed',
    this.sortOrder = 0,
    this.progress = 1.0,
    this.localPath,
    this.localBytes,
  });

  bool get isImage => mediaType == 'image' || mediaType == 'photo';
  bool get isVideo => mediaType == 'video';
  bool get isVoice => mediaType == 'voice' || mediaType == 'audio';
  bool get isDocument => mediaType == 'document' || mediaType == 'file';
  bool get isUploading => uploadStatus == 'uploading' || uploadStatus == 'pending';
  bool get isFailed => uploadStatus == 'failed';
  bool get isCompleted => uploadStatus == 'completed';

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      messageId: (json['message_id'] as num?)?.toInt() ?? 0,
      mediaType: json['media_type']?.toString() ?? 'file',
      mimeType: json['mime_type']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      storageKey: json['storage_key']?.toString(),
      url: json['url']?.toString() ?? '',
      uploadStatus: json['upload_status']?.toString() ?? 'completed',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
      localPath: json['local_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      if (messageId > 0) 'message_id': messageId,
      'media_type': mediaType,
      'mime_type': mimeType,
      'file_name': fileName,
      'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (storageKey != null) 'storage_key': storageKey,
      'url': url,
      'upload_status': uploadStatus,
      'sort_order': sortOrder,
      'progress': progress,
      if (localPath != null) 'local_path': localPath,
      if (localBytes != null) 'local_bytes': localBytes,
    };
  }

  MessageAttachment copyWith({
    int? id,
    int? messageId,
    String? mediaType,
    String? mimeType,
    String? fileName,
    int? sizeBytes,
    int? width,
    int? height,
    int? durationMs,
    String? storageKey,
    String? url,
    String? uploadStatus,
    int? sortOrder,
    double? progress,
    String? localPath,
    List<int>? localBytes,
  }) {
    return MessageAttachment(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      mediaType: mediaType ?? this.mediaType,
      mimeType: mimeType ?? this.mimeType,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      storageKey: storageKey ?? this.storageKey,
      url: url ?? this.url,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      sortOrder: sortOrder ?? this.sortOrder,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      localBytes: localBytes ?? this.localBytes,
    );
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final int? groupId;
  final String? clientMessageId;
  final String username;
  final String? senderAvatar;
  final String content;
  final String status; // pending, uploading, sent, delivered, read, failed
  final String mediaType;
  final String? mediaUrl;
  final String? forwardFrom;
  final String? reactions;
  final int? durationMs;
  final String? waveform;
  final bool isRead;
  final DateTime? readAt;
  final int seenCount;
  final List<Map<String, dynamic>> seenBy;
  final List<MessageAttachment> attachments;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.groupId,
    this.clientMessageId,
    required this.username,
    this.senderAvatar,
    required this.content,
    this.status = 'sent',
    this.mediaType = 'text',
    this.mediaUrl,
    this.durationMs,
    this.waveform,
    this.forwardFrom,
    this.reactions,
    this.isRead = false,
    this.readAt,
    this.seenCount = 0,
    this.seenBy = const [],
    this.attachments = const [],
    required this.timestamp,
  });

  bool get isGroupMessage => groupId != null && groupId! > 0;

  bool get isVoice => mediaType == 'voice' || mediaType == 'audio' || (attachments.length == 1 && attachments.first.isVoice);
  bool get isImage => mediaType == 'image' || mediaType == 'photo' || (attachments.length == 1 && attachments.first.isImage);
  bool get isVideo => mediaType == 'video' || (attachments.length == 1 && attachments.first.isVideo);
  bool get isLocation => mediaType == 'location' || content.contains('📍');
  bool get isFile => mediaType == 'file' || mediaType == 'document' || (attachments.length == 1 && attachments.first.isDocument);
  bool get isAlbum => mediaType == 'album' || (attachments.length > 1 && attachments.every((a) => a.isImage || a.isVideo));
  bool get hasAttachments => attachments.isNotEmpty;
  bool get isMultiFile => attachments.length > 1 && attachments.any((a) => a.isDocument);

  List<double> get waveformList {
    if (waveform == null || waveform!.isEmpty) {
      // Default placeholder waveform heights (28 bars)
      return const [
        0.2, 0.4, 0.6, 0.3, 0.7, 0.9, 0.5, 0.3, 0.8, 1.0, 0.6, 0.4, 0.7, 0.5,
        0.3, 0.6, 0.8, 0.9, 0.4, 0.6, 0.7, 0.5, 0.3, 0.6, 0.4, 0.5, 0.3, 0.2
      ];
    }
    try {
      final decoded = jsonDecode(waveform!);
      if (decoded is List) {
        return decoded
            .map((e) => (e as num).toDouble().clamp(0.1, 1.0))
            .toList();
      }
    } catch (_) {}
    return const [
      0.2, 0.4, 0.6, 0.3, 0.7, 0.9, 0.5, 0.3, 0.8, 1.0, 0.6, 0.4, 0.7, 0.5,
      0.3, 0.6, 0.8, 0.9, 0.4, 0.6, 0.7, 0.5, 0.3, 0.6, 0.4, 0.5, 0.3, 0.2
    ];
  }

  Map<String, List<int>> get reactionMap {
    if (reactions == null || reactions!.isEmpty) return {};
    try {
      final decoded = jsonDecode(reactions!);
      if (decoded is Map<String, dynamic>) {
        final result = <String, List<int>>{};
        decoded.forEach((key, val) {
          if (val is List) {
            result[key] = val.map((e) => (e as num).toInt()).toList();
          }
        });
        return result;
      }
    } catch (_) {}
    return {};
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(dynamic raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString()) ?? DateTime.now();
    }

    final rawAttachments = json['attachments'];
    List<MessageAttachment> parsedAttachments = [];
    if (rawAttachments is List) {
      parsedAttachments = rawAttachments
          .whereType<Map>()
          .map((e) => MessageAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ChatMessage(
      id: json['id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      receiverId: json['receiver_id'] ?? 0,
      groupId: (json['group_id'] as num?)?.toInt(),
      clientMessageId: json['client_message_id']?.toString(),
      username: json['username'] ?? '',
      senderAvatar: json['sender_avatar']?.toString() ?? json['avatar_url']?.toString(),
      content: json['content'] ?? '',
      status: json['status']?.toString() ?? 'sent',
      mediaType: json['media_type'] ?? 'text',
      mediaUrl: json['media_url'],
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      waveform: json['waveform']?.toString(),
      forwardFrom: json['forward_from']?.toString(),
      reactions: json['reactions']?.toString(),
      isRead: json['is_read'] == true || json['is_read'] == 1 || json['is_read'] == 'true',
      readAt: json['read_at'] != null ? parseTime(json['read_at']) : null,
      seenCount: (json['seen_count'] as num?)?.toInt() ??
          ((json['seen_by'] is List) ? (json['seen_by'] as List).length : ((json['is_read'] == true) ? 1 : 0)),
      seenBy: (json['seen_by'] is List)
          ? (json['seen_by'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const [],
      attachments: parsedAttachments,
      timestamp: parseTime(json['timestamp'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      if (groupId != null && groupId! > 0) 'group_id': groupId,
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      'username': username,
      'sender_avatar': senderAvatar,
      'content': content,
      'status': status,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'duration_ms': durationMs,
      'waveform': waveform,
      'forward_from': forwardFrom,
      'reactions': reactions,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'seen_count': seenCount,
      if (seenBy.isNotEmpty) 'seen_by': seenBy,
      if (attachments.isNotEmpty) 'attachments': attachments.map((a) => a.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    int? groupId,
    String? clientMessageId,
    String? username,
    String? senderAvatar,
    String? content,
    String? status,
    String? mediaType,
    String? mediaUrl,
    int? durationMs,
    String? waveform,
    String? forwardFrom,
    String? reactions,
    bool? isRead,
    DateTime? readAt,
    int? seenCount,
    List<Map<String, dynamic>>? seenBy,
    List<MessageAttachment>? attachments,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId ?? this.groupId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      username: username ?? this.username,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      status: status ?? this.status,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      durationMs: durationMs ?? this.durationMs,
      waveform: waveform ?? this.waveform,
      forwardFrom: forwardFrom ?? this.forwardFrom,
      reactions: reactions ?? this.reactions,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      seenCount: seenCount ?? this.seenCount,
      seenBy: seenBy ?? this.seenBy,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class ChatConversation {
  final String conversationId;
  final String name;
  final String avatarUrl;
  final String lastMessageText;
  final ChatMessage? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final dynamic lastMessageId;
  final bool isPinned;
  final bool isMuted;
  final UserModel user;

  ChatConversation({
    String? conversationId,
    String? name,
    String? avatarUrl,
    String? lastMessageText,
    this.lastMessage,
    DateTime? lastMessageAt,
    this.unreadCount = 0,
    this.lastMessageId,
    this.isPinned = false,
    this.isMuted = false,
    required this.user,
  })  : conversationId = conversationId ?? (user.id != 0 ? 'chat_${user.id}' : ''),
        name = name ?? (user.displayName.isNotEmpty ? user.displayName : user.username),
        avatarUrl = avatarUrl ?? user.avatarUrl,
        lastMessageText = lastMessageText ?? (lastMessage?.content ?? ''),
        lastMessageAt = lastMessageAt ?? lastMessage?.timestamp;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    UserModel userObj;
    if (json['user'] is Map<String, dynamic>) {
      userObj = UserModel.fromJson(json['user']);
    } else {
      final convIdStr = json['conversation_id']?.toString() ?? json['conversationId']?.toString() ?? '';
      final parsedId = int.tryParse(convIdStr.replaceFirst('chat_', '')) ?? 0;
      userObj = UserModel(
        id: parsedId,
        uuid: '$parsedId',
        username: json['name']?.toString() ?? 'User $parsedId',
        email: '',
        displayName: json['name']?.toString() ?? 'User $parsedId',
        avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString() ?? '',
        isOnline: false,
        lastSeenAt: null,
        createdAt: DateTime.now(),
      );
    }

    ChatMessage? msg;
    if (json['last_message'] is Map<String, dynamic>) {
      msg = ChatMessage.fromJson(json['last_message']);
    }

    DateTime? msgAt;
    final timeRaw = json['last_message_at'] ?? json['lastMessageAt'];
    if (timeRaw != null) {
      msgAt = DateTime.tryParse(timeRaw.toString())?.toLocal();
    } else if (msg != null) {
      msgAt = msg.timestamp;
    }

    final rawLastMessage = json['lastMessage'] ?? json['last_message_text'];
    final text = rawLastMessage is String ? rawLastMessage : (msg?.content ?? '');

    return ChatConversation(
      conversationId: json['conversation_id']?.toString() ?? json['conversationId']?.toString() ?? 'chat_${userObj.id}',
      name: json['name']?.toString() ?? (userObj.displayName.isNotEmpty ? userObj.displayName : userObj.username),
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString() ?? userObj.avatarUrl,
      lastMessageText: text,
      lastMessage: msg,
      lastMessageAt: msgAt,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessageId: json['last_message_id'] ?? json['lastMessageId'] ?? msg?.id,
      isPinned: json['is_pinned'] == true || json['isPinned'] == true,
      isMuted: json['is_muted'] == true || json['isMuted'] == true,
      user: userObj,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'name': name,
      'avatar_url': avatarUrl,
      'last_message_text': lastMessageText,
      if (lastMessage != null) 'last_message': lastMessage!.toJson(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'last_message_id': lastMessageId,
      'is_pinned': isPinned,
      'is_muted': isMuted,
      'user': user.toJson(),
    };
  }

  ChatConversation copyWith({
    String? conversationId,
    String? name,
    String? avatarUrl,
    String? lastMessageText,
    ChatMessage? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    dynamic lastMessageId,
    bool? isPinned,
    bool? isMuted,
    UserModel? user,
  }) {
    return ChatConversation(
      conversationId: conversationId ?? this.conversationId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      user: user ?? this.user,
    );
  }
}

