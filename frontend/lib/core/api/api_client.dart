import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/chat_message.dart';
import '../../models/group_model.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  ApiClient._internal();

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8088/api/v1';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8088/api/v1';
      }
    } catch (_) {}
    return 'http://localhost:8088/api/v1';
  }

  String get wsUrl {
    if (kIsWeb) {
      return 'ws://localhost:8088/api/v1/ws';
    }
    try {
      if (Platform.isAndroid) {
        return 'ws://10.0.2.2:8088/api/v1/ws';
      }
    } catch (_) {}
    return 'ws://localhost:8088/api/v1/ws';
  }

  // Register User
  Future<AuthData> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'display_name': displayName?.trim().isNotEmpty == true ? displayName : username,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      final authData = AuthData.fromJson(data['data']);
      await saveTokens(authData.accessToken, authData.refreshToken);
      return authData;
    } else {
      throw Exception(data['error'] ?? 'Registration failed');
    }
  }

  // Login User
  Future<AuthData> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username_or_email': usernameOrEmail.trim(),
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final authData = AuthData.fromJson(data['data']);
      await saveTokens(authData.accessToken, authData.refreshToken);
      return authData;
    } else {
      throw Exception(data['error'] ?? 'Invalid credentials');
    }
  }

  // Get current user profile
  Future<UserModel> getMe() async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final url = Uri.parse('$baseUrl/auth/me');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return UserModel.fromJson(data['data']);
    } else {
      throw Exception(data['error'] ?? 'Failed fetching profile');
    }
  }

  // List all users with optional pagination and search
  Future<List<UserModel>> listUsers({int limit = 100, int offset = 0, String? search}) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse('$baseUrl/users').replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = data['data'] as List;
      return list.map((u) => UserModel.fromJson(u)).toList();
    } else {
      throw Exception(data['error'] ?? 'Failed fetching users');
    }
  }

  // Fetch authorized profile of a specific user
  Future<UserModel> getUserProfile(int userId) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final url = Uri.parse('$baseUrl/users/$userId');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['data'] != null) {
      return UserModel.fromJson(data['data']);
    } else {
      throw Exception(data['error'] ?? 'Failed fetching user profile');
    }
  }

  // Get shared media, documents, and links for conversation
  Future<List<Map<String, dynamic>>> getSharedMedia(int partnerId, {String? type, int limit = 500, int offset = 0}) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final queryParams = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }

    final uri = Uri.parse('$baseUrl/chats/$partnerId/media').replace(
      queryParameters: queryParams,
    );
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['data'] != null) {
      final list = data['data'] as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      throw Exception(data['error'] ?? 'Failed fetching shared media');
    }
  }

  // Resolve media / avatar URL through the streaming route if public bucket access is disabled
  static String resolveAvatarUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    var resolved = url.trim();
    if (resolved.contains('.r2.dev/')) {
      final key = resolved.split('.r2.dev/').last;
      resolved = '${instance.baseUrl}/media/file/$key';
    } else if (resolved.startsWith('/api/v1/')) {
      resolved = '${instance.baseUrl}${resolved.replaceFirst('/api/v1', '')}';
    } else if (resolved.startsWith('/media/file/')) {
      resolved = '${instance.baseUrl}$resolved';
    }
    try {
      if (Platform.isAndroid) {
        if (resolved.contains('localhost:8088')) {
          resolved = resolved.replaceAll('localhost:8088', '10.0.2.2:8088');
        } else if (resolved.contains('127.0.0.1:8088')) {
          resolved = resolved.replaceAll('127.0.0.1:8088', '10.0.2.2:8088');
        }
      }
    } catch (_) {}
    return resolved;
  }

  // Upload user avatar to Cloudflare R2
  Future<String> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/users/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['avatar_url'] as String;
    } else {
      throw Exception(data['error'] ?? 'Failed to upload avatar');
    }
  }

  // Update user profile (display name and username)
  Future<UserModel> updateProfile({
    String? displayName,
    String? username,
  }) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/users/profile');
    final payload = <String, dynamic>{};
    if (displayName != null) payload['display_name'] = displayName;
    if (username != null) payload['username'] = username;

    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return UserModel.fromJson(data['data']);
    } else {
      throw Exception(data['error'] ?? 'Failed to update profile');
    }
  }

  // Chat API Methods
  Future<List<ChatConversation>> getConversations() async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/chats/conversations');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = (data['data'] as List?) ?? [];
      return list.map((c) => ChatConversation.fromJson(c)).toList();
    } else {
      throw Exception(data['error'] ?? 'Failed to load conversations');
    }
  }

  Future<List<ChatMessage>> getMessages(int partnerId, {int limit = 50, int offset = 0, int? before}) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (before != null && before > 0) {
      query['before'] = before.toString();
    }

    final uri = Uri.parse('$baseUrl/chats/$partnerId/messages').replace(queryParameters: query);
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = (data['data'] as List?) ?? [];
      return list.map((m) => ChatMessage.fromJson(m)).toList();
    } else {
      throw Exception(data['error'] ?? 'Failed to load messages');
    }
  }

  Future<ChatMessage> sendChatMessage({
    required int receiverId,
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
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/chats/messages');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'receiver_id': receiverId,
        if (clientMessageId != null && clientMessageId.isNotEmpty) 'client_message_id': clientMessageId,
        'content': content,
        if (status != null && status.isNotEmpty) 'status': status,
        'media_type': mediaType,
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'media_url': mediaUrl,
        if (durationMs != null && durationMs > 0) 'duration_ms': durationMs,
        if (waveform != null && waveform.isNotEmpty) 'waveform': waveform,
        if (forwardFrom != null && forwardFrom.isNotEmpty) 'forward_from': forwardFrom,
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return ChatMessage.fromJson(data['data']);
    } else {
      throw Exception(data['error'] ?? 'Failed to send message');
    }
  }

  Future<void> markChatRead(int partnerId) async {
    final token = await getAccessToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('$baseUrl/chats/$partnerId/read');
      await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
  }

  Future<void> deleteMessage(int messageId, {bool forEveryone = false}) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/chats/messages/$messageId?everyone=$forEveryone');
    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to delete message');
    }
  }

  Future<void> deleteConversation(int partnerId, {bool forEveryone = false}) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/chats/$partnerId?everyone=$forEveryone');
    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to delete conversation');
    }
  }

  Future<String> reactToMessage(int messageId, String emoji) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/chats/messages/$messageId/reaction');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'emoji': emoji}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['reactions'] ?? '') as String;
    } else {
      throw Exception(data['error'] ?? 'Failed to react to message');
    }
  }

  // Upload chat media (photos/attachments) to Cloudflare R2 with live streaming progress
  Future<String> uploadChatMedia({
    List<int>? bytes,
    String? filePath,
    required String filename,
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final safeFilename = (filename.trim().isNotEmpty && filename.contains('.'))
        ? filename.trim()
        : 'file_${DateTime.now().millisecondsSinceEpoch}_$filename.jpg';

    final uri = Uri.parse('$baseUrl/media/upload');
    final request = MultipartRequestWithProgress(
      'POST',
      uri,
      onProgress: onProgress,
    );
    request.headers['Authorization'] = 'Bearer $token';

    if (filePath != null && !kIsWeb) {
      final file = File(filePath);
      if (await file.exists()) {
        final length = await file.length();
        final stream = http.ByteStream(file.openRead());
        request.files.add(http.MultipartFile(
          'file',
          stream,
          length,
          filename: safeFilename,
        ));
      } else if (bytes != null && bytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: safeFilename,
        ));
      } else {
        throw Exception('File not found at $filePath');
      }
    } else if (bytes != null && bytes.isNotEmpty) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: safeFilename,
      ));
    } else {
      throw Exception('No file data provided for upload');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final url = data['data']?['url'] ?? data['url'] ?? data['media_url'] ?? data['avatar_url'];
      return (url ?? '') as String;
    } else {
      throw Exception(data['error'] ?? 'Failed to upload media');
    }
  }

  // Token storage
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Group Chat API
  Future<ChatGroup> createGroup({
    required String name,
    String? description,
    String? avatarUrl,
    List<int>? memberIds,
  }) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/groups');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name.trim(),
        if (description != null && description.isNotEmpty) 'description': description.trim(),
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
        if (memberIds != null && memberIds.isNotEmpty) 'member_ids': memberIds,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return ChatGroup.fromJson(data['data']);
    } else {
      throw Exception(data['error'] ?? 'Failed to create group');
    }
  }

  Future<List<ChatGroup>> getGroups() async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/groups');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List list = data['data'] ?? [];
      return list.map((g) => ChatGroup.fromJson(g)).toList();
    } else {
      throw Exception(data['error'] ?? 'Failed to fetch groups');
    }
  }

  Future<ChatGroup> getGroup(int groupId) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/groups/$groupId');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ChatGroup.fromJson(data['data']);
    } else {
      throw Exception(data['error'] ?? 'Failed to fetch group details');
    }
  }

  Future<ChatGroup> updateGroup(int groupId, {String? name, String? description, String? avatarUrl}) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/groups/$groupId');
    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ChatGroup.fromJson(data['data']);
    } else {
      throw Exception(data['error'] ?? 'Failed to update group');
    }
  }

  Future<void> addGroupMembers(int groupId, List<int> memberIds) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/groups/$groupId/members');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'member_ids': memberIds}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to add members');
    }
  }

  Future<void> removeGroupMember(int groupId, int userId) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/groups/$groupId/members/$userId');
    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to remove member');
    }
  }

  Future<void> leaveGroup(int groupId) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/groups/$groupId/leave');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to leave group');
    }
  }

  Future<List<ChatMessage>> getGroupMessages(int groupId, {int limit = 50, int offset = 0, int? before}) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    String query = 'limit=$limit&offset=$offset';
    if (before != null && before > 0) {
      query += '&before=$before';
    }

    final uri = Uri.parse('$baseUrl/groups/$groupId/messages?$query');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List list = data['data'] ?? [];
      return list.map((m) => ChatMessage.fromJson(m)).toList();
    } else {
      throw Exception(data['error'] ?? 'Failed to fetch group messages');
    }
  }

  Future<ChatMessage> sendGroupMessage(
    int groupId, {
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
    final token = await getAccessToken();
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('$baseUrl/groups/$groupId/messages');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'receiver_id': 0,
        'group_id': groupId,
        if (clientMessageId != null && clientMessageId.isNotEmpty) 'client_message_id': clientMessageId,
        'content': content,
        if (status != null && status.isNotEmpty) 'status': status,
        'media_type': mediaType,
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'media_url': mediaUrl,
        if (durationMs != null && durationMs > 0) 'duration_ms': durationMs,
        if (waveform != null && waveform.isNotEmpty) 'waveform': waveform,
        if (forwardFrom != null && forwardFrom.isNotEmpty) 'forward_from': forwardFrom,
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return ChatMessage.fromJson(data['data']);
    } else {
      throw Exception(data['error'] ?? 'Failed to send group message');
    }
  }

  Future<void> markGroupRead(int groupId) async {
    final token = await getAccessToken();
    if (token == null) return;
    try {
      final uri = Uri.parse('$baseUrl/groups/$groupId/read');
      await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getGroupMessageReaders(int groupId, int messageId) async {
    final token = await getAccessToken();
    if (token == null) return [];
    try {
      final uri = Uri.parse('$baseUrl/groups/$groupId/messages/$messageId/readers');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List list = data['data'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> logout() async {
    final token = await getAccessToken();
    if (token != null) {
      try {
        final url = Uri.parse('$baseUrl/auth/logout');
        await http.post(
          url,
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}

/// Custom MultipartRequest that instruments the underlying ByteStream to report upload progress in real-time
class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(int bytesSent, int totalBytes)? onProgress;

  MultipartRequestWithProgress(
    super.method,
    super.url, {
    this.onProgress,
  });

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final total = contentLength;
    int bytesSent = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesSent += data.length;
        sink.add(data);
        if (total > 0) {
          onProgress!(bytesSent, total);
        }
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}
