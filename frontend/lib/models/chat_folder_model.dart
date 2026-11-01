import 'package:flutter/cupertino.dart';

/// Represents a Chat Folder (e.g. "Personal", "Unread", "Work", "My Files").
class ChatFolder {
  final String id;
  final String name;
  final String iconKey;
  final bool isSystem;
  final int order;

  // Criteria rules
  final bool includePersonal; // Direct 1-on-1 chats
  final bool includeGroups; // Group chats
  final bool includeUnreadOnly; // Only unread chats
  final bool includeContacts; // Contacts
  final bool includeNonContacts; // Unknown / non-contacts

  // Explicit IDs
  final List<int> includedUserIds;
  final List<int> includedGroupIds;
  final List<int> excludedUserIds;
  final List<int> excludedGroupIds;

  // Exclude criteria
  final bool excludeMuted;
  final bool excludeRead;
  final bool excludeArchived;

  const ChatFolder({
    required this.id,
    required this.name,
    this.iconKey = 'folder',
    this.isSystem = false,
    this.order = 0,
    this.includePersonal = true,
    this.includeGroups = true,
    this.includeUnreadOnly = false,
    this.includeContacts = true,
    this.includeNonContacts = true,
    this.includedUserIds = const [],
    this.includedGroupIds = const [],
    this.excludedUserIds = const [],
    this.excludedGroupIds = const [],
    this.excludeMuted = false,
    this.excludeRead = false,
    this.excludeArchived = false,
  });

  /// Map of available folder icons.
  static final Map<String, IconData> availableIcons = {
    'folder': CupertinoIcons.folder_fill,
    'chat': CupertinoIcons.chat_bubble_2_fill,
    'person': CupertinoIcons.person_fill,
    'people': CupertinoIcons.person_2_fill,
    'star': CupertinoIcons.star_fill,
    'work': CupertinoIcons.briefcase_fill,
    'tag': CupertinoIcons.tag_fill,
    'heart': CupertinoIcons.heart_fill,
    'doc': CupertinoIcons.doc_text_fill,
    'bell': CupertinoIcons.bell_fill,
    'bookmark': CupertinoIcons.bookmark_fill,
    'flame': CupertinoIcons.flame_fill,
  };

  IconData get iconData => availableIcons[iconKey] ?? CupertinoIcons.folder_fill;

  ChatFolder copyWith({
    String? id,
    String? name,
    String? iconKey,
    bool? isSystem,
    int? order,
    bool? includePersonal,
    bool? includeGroups,
    bool? includeUnreadOnly,
    bool? includeContacts,
    bool? includeNonContacts,
    List<int>? includedUserIds,
    List<int>? includedGroupIds,
    List<int>? excludedUserIds,
    List<int>? excludedGroupIds,
    bool? excludeMuted,
    bool? excludeRead,
    bool? excludeArchived,
  }) {
    return ChatFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      isSystem: isSystem ?? this.isSystem,
      order: order ?? this.order,
      includePersonal: includePersonal ?? this.includePersonal,
      includeGroups: includeGroups ?? this.includeGroups,
      includeUnreadOnly: includeUnreadOnly ?? this.includeUnreadOnly,
      includeContacts: includeContacts ?? this.includeContacts,
      includeNonContacts: includeNonContacts ?? this.includeNonContacts,
      includedUserIds: includedUserIds ?? this.includedUserIds,
      includedGroupIds: includedGroupIds ?? this.includedGroupIds,
      excludedUserIds: excludedUserIds ?? this.excludedUserIds,
      excludedGroupIds: excludedGroupIds ?? this.excludedGroupIds,
      excludeMuted: excludeMuted ?? this.excludeMuted,
      excludeRead: excludeRead ?? this.excludeRead,
      excludeArchived: excludeArchived ?? this.excludeArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconKey': iconKey,
      'isSystem': isSystem,
      'order': order,
      'includePersonal': includePersonal,
      'includeGroups': includeGroups,
      'includeUnreadOnly': includeUnreadOnly,
      'includeContacts': includeContacts,
      'includeNonContacts': includeNonContacts,
      'includedUserIds': includedUserIds,
      'includedGroupIds': includedGroupIds,
      'excludedUserIds': excludedUserIds,
      'excludedGroupIds': excludedGroupIds,
      'excludeMuted': excludeMuted,
      'excludeRead': excludeRead,
      'excludeArchived': excludeArchived,
    };
  }

  factory ChatFolder.fromJson(Map<String, dynamic> json) {
    return ChatFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      iconKey: json['iconKey'] as String? ?? 'folder',
      isSystem: json['isSystem'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
      includePersonal: json['includePersonal'] as bool? ?? true,
      includeGroups: json['includeGroups'] as bool? ?? true,
      includeUnreadOnly: json['includeUnreadOnly'] as bool? ?? false,
      includeContacts: json['includeContacts'] as bool? ?? true,
      includeNonContacts: json['includeNonContacts'] as bool? ?? true,
      includedUserIds: (json['includedUserIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      includedGroupIds: (json['includedGroupIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      excludedUserIds: (json['excludedUserIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      excludedGroupIds: (json['excludedGroupIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      excludeMuted: json['excludeMuted'] as bool? ?? false,
      excludeRead: json['excludeRead'] as bool? ?? false,
      excludeArchived: json['excludeArchived'] as bool? ?? false,
    );
  }

  static List<ChatFolder> getDefaultFolders() {
    return const [
      ChatFolder(
        id: 'all_chats',
        name: 'All Chats',
        iconKey: 'chat',
        isSystem: true,
        order: 0,
        includePersonal: true,
        includeGroups: true,
        includeUnreadOnly: false,
      ),
      ChatFolder(
        id: 'my_files',
        name: 'My Files',
        iconKey: 'doc',
        isSystem: false,
        order: 1,
        includePersonal: true,
        includeGroups: false,
      ),
      ChatFolder(
        id: 'personal',
        name: 'Personal',
        iconKey: 'person',
        isSystem: false,
        order: 2,
        includePersonal: true,
        includeGroups: false,
        includeUnreadOnly: false,
      ),
      ChatFolder(
        id: 'unread',
        name: 'Unread',
        iconKey: 'bell',
        isSystem: false,
        order: 3,
        includePersonal: true,
        includeGroups: true,
        includeUnreadOnly: true,
      ),
    ];
  }
}
