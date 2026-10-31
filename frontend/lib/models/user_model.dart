class UserModel {
  final int id;
  final String uuid;
  final String username;
  final String email;
  final String displayName;
  final String avatarUrl;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.uuid,
    required this.username,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.isOnline,
    this.lastSeenAt,
    required this.createdAt,
  });

  UserModel copyWith({
    int? id,
    String? uuid,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeenAt,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      uuid: json['uuid'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      isOnline: json['is_online'] == true || json['is_online'] == 1 || json['is_online'] == 'true',
      lastSeenAt: json['last_seen_at'] != null ? DateTime.tryParse(json['last_seen_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'username': username,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AuthData {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserModel user;

  AuthData({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      expiresIn: json['expires_in'] ?? 86400,
      user: UserModel.fromJson(json['user'] ?? {}),
    );
  }
}
