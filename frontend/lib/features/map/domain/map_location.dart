import 'dart:convert';

/// Represents a geographic point with optional metadata (name, address, accuracy, timestamp).
class MapLocation {
  final double latitude;
  final double longitude;
  final String? name;
  final String? address;
  final double? accuracy;
  final DateTime? timestamp;

  const MapLocation({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
    this.accuracy,
    this.timestamp,
  });

  static const MapLocation phnomPenh = MapLocation(
    latitude: 11.5621,
    longitude: 104.9282,
    name: 'Phnom Penh',
    address: 'Phnom Penh, Cambodia',
  );

  /// Formatted short display name (concise street or place name, omitting long administrative details)
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) {
      final clean = name!.replaceAll('📍', '').trim();
      final firstPart = clean.split(RegExp(r'[,;\n]')).first.trim();
      if (firstPart.isNotEmpty) return firstPart;
    }
    if (address != null && address!.trim().isNotEmpty) {
      final clean = address!.replaceAll('📍', '').trim();
      final firstPart = clean.split(RegExp(r'[,;\n]')).first.trim();
      if (firstPart.isNotEmpty) return firstPart;
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  /// Full descriptive address or place name
  String get fullAddress {
    if (address != null && address!.trim().isNotEmpty) return address!.replaceAll('📍', '').trim();
    if (name != null && name!.trim().isNotEmpty) return name!.replaceAll('📍', '').trim();
    return coordinateString;
  }

  /// Formatted coordinates string
  String get coordinateString =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  /// Serializes into JSON format for chat message payloads
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (accuracy != null) 'accuracy': accuracy,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }

  /// Parses from a JSON map
  factory MapLocation.fromJson(Map<String, dynamic> json) {
    return MapLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 11.5621,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 104.9282,
      name: json['name'] as String?,
      address: json['address'] as String?,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }

  /// Parses geo: URI or textual location message content
  factory MapLocation.parseContent(String content) {
    // 1. Try geo:lat,lon regex
    final geoMatch =
        RegExp(r'geo:(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(content);
    double lat = 11.5621;
    double lon = 104.9282;

    if (geoMatch != null) {
      lat = double.tryParse(geoMatch.group(1) ?? '') ?? 11.5621;
      lon = double.tryParse(geoMatch.group(2) ?? '') ?? 104.9282;
    }

    // Check if content is formatted JSON
    if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          if (decoded['location'] is Map<String, dynamic>) {
            return MapLocation.fromJson(
                decoded['location'] as Map<String, dynamic>);
          }
          return MapLocation.fromJson(decoded);
        }
      } catch (_) {}
    }

    // Try extracting lines for name & address
    final lines = content
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('geo:'))
        .toList();

    String? placeName;
    String? placeAddress;

    if (lines.isNotEmpty) {
      placeName = lines.first.replaceAll('📍', '').trim();
      if (lines.length > 1) {
        placeAddress = lines.sublist(1).join(', ').trim();
      }
    }

    return MapLocation(
      latitude: lat,
      longitude: lon,
      name: placeName,
      address: placeAddress,
    );
  }

  /// Creates a standard text content representation for backwards compatibility
  String toChatContent() {
    final title = displayName;
    final addr = address ?? '';
    final geo = 'geo:$latitude,$longitude';
    if (addr.isNotEmpty && addr != title) {
      return '📍 $title\n$addr\n$geo';
    }
    return '📍 $title\n$geo';
  }

  MapLocation copyWith({
    double? latitude,
    double? longitude,
    String? name,
    String? address,
    double? accuracy,
    DateTime? timestamp,
  }) {
    return MapLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      name: name ?? this.name,
      address: address ?? this.address,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Model for live location sharing sessions
class LiveLocationSession {
  final String sessionId;
  final int userId;
  final String username;
  final String? avatarUrl;
  final MapLocation location;
  final DateTime startedAt;
  final DateTime expiresAt;
  final bool isSharing;

  const LiveLocationSession({
    required this.sessionId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.location,
    required this.startedAt,
    required this.expiresAt,
    required this.isSharing,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime =>
      expiresAt.difference(DateTime.now()).isNegative
          ? Duration.zero
          : expiresAt.difference(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'location': location.toJson(),
      'started_at': startedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_sharing': isSharing,
    };
  }

  factory LiveLocationSession.fromJson(Map<String, dynamic> json) {
    return LiveLocationSession(
      sessionId: json['session_id'] as String? ?? '',
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      location: json['location'] is Map<String, dynamic>
          ? MapLocation.fromJson(json['location'] as Map<String, dynamic>)
          : MapLocation.phnomPenh,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString()) ?? DateTime.now()
          : DateTime.now().add(const Duration(minutes: 15)),
      isSharing: json['is_sharing'] as bool? ?? true,
    );
  }
}
