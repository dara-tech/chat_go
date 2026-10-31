import 'chat_message.dart';
import 'user_model.dart';

class GroupMember {
  final int id;
  final int groupId;
  final int userId;
  final String role; // 'admin', 'member'
  final DateTime joinedAt;
  final UserModel? user;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    this.role = 'member',
    required this.joinedAt,
    this.user,
  });

  bool get isAdmin => role == 'admin';

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: (json['id'] as num?)?.toInt() ?? 0,
      groupId: (json['group_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      role: json['role']?.toString() ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      user: json['user'] != null && json['user'] is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(json['user']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
    };
  }
}

class ChatGroup {
  final int id;
  final String name;
  final String description;
  final String avatarUrl;
  final int creatorId;
  final int memberCount;
  final List<GroupMember> members;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatGroup({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    required this.creatorId,
    this.memberCount = 0,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatGroup copyWith({
    int? id,
    String? name,
    String? description,
    String? avatarUrl,
    int? creatorId,
    int? memberCount,
    List<GroupMember>? members,
    ChatMessage? lastMessage,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      creatorId: creatorId ?? this.creatorId,
      memberCount: memberCount ?? this.memberCount,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(dynamic raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString()) ?? DateTime.now();
    }

    final rawMembers = json['members'];
    List<GroupMember> parsedMembers = [];
    if (rawMembers is List) {
      parsedMembers = rawMembers
          .whereType<Map>()
          .map((m) => GroupMember.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    ChatMessage? lastMsg;
    if (json['last_message'] != null && json['last_message'] is Map) {
      lastMsg = ChatMessage.fromJson(Map<String, dynamic>.from(json['last_message']));
    }

    final count = (json['member_count'] as num?)?.toInt() ?? parsedMembers.length;

    return ChatGroup(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Group',
      description: json['description']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      creatorId: (json['creator_id'] as num?)?.toInt() ?? 0,
      memberCount: count,
      members: parsedMembers,
      lastMessage: lastMsg,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      createdAt: parseTime(json['created_at']),
      updatedAt: parseTime(json['updated_at'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'creator_id': creatorId,
      'member_count': memberCount,
      'members': members.map((m) => m.toJson()).toList(),
      if (lastMessage != null) 'last_message': lastMessage!.toJson(),
      'unread_count': unreadCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
