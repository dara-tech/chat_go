import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_client.dart';

enum SocketConnectionState {
  connecting, // Initiating connection / handshake
  connected, // Successfully connected & authenticated
  reconnecting, // Connection lost, retrying
  waitingForNetwork, // Offline / no token available
  disconnected, // Explicitly disconnected (e.g. on logout)
}

class ChatSocketService with WidgetsBindingObserver {
  static final ChatSocketService instance = ChatSocketService._internal();
  ChatSocketService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  WebSocketChannel? _channel;
  bool _isExplicitDisconnect = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastMessageReceivedAt;

  int _reconnectAttempts = 0;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  // Reactive Connection State Notifier
  final ValueNotifier<SocketConnectionState> connectionStateNotifier =
      ValueNotifier<SocketConnectionState>(SocketConnectionState.disconnected);

  // Reactive Set of all currently online user IDs
  final ValueNotifier<Set<int>> onlineUserIdsNotifier =
      ValueNotifier<Set<int>>(<int>{});

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  SocketConnectionState get state => connectionStateNotifier.value;
  SocketConnectionState get connectionState => connectionStateNotifier.value;
  bool get isConnected =>
      connectionStateNotifier.value == SocketConnectionState.connected;
  Set<int> get onlineUserIds => onlineUserIdsNotifier.value;

  /// Check if a specific user is currently active/online
  bool isUserOnline(int userId) => onlineUserIdsNotifier.value.contains(userId);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('[WS] App resumed to foreground. Checking socket connection...');
      }
      if (!_isExplicitDisconnect && !isConnected) {
        connect();
      }
    }
  }

  /// Connects or reconnects to the WebSocket server
  Future<void> connect() async {
    if (isConnected && _channel != null) return;

    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _isExplicitDisconnect = false;

    final token = await ApiClient.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      _setConnectionState(SocketConnectionState.waitingForNetwork);
      return;
    }

    _setConnectionState(_reconnectAttempts > 0
        ? SocketConnectionState.reconnecting
        : SocketConnectionState.connecting);

    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    final wsUri = Uri.parse(
        '${ApiClient.instance.wsUrl}?token=${Uri.encodeComponent(token)}');

    if (kDebugMode) {
      print('[WS] Connecting to $wsUri (attempt: $_reconnectAttempts)...');
    }

    try {
      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;

      channel.stream.listen(
        (data) {
          _lastMessageReceivedAt = DateTime.now();
          _onIncomingData(data);
        },
        onDone: () {
          if (kDebugMode) {
            print('[WS] Disconnected (onDone)');
          }
          _handleDisconnect();
        },
        onError: (err) {
          if (kDebugMode) {
            print('[WS] Error: $err');
          }
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // Start periodic ping-pong heartbeat
      _startHeartbeat();
    } catch (e) {
      if (kDebugMode) {
        print('[WS] Connection exception: $e');
      }
      _handleDisconnect();
    }
  }

  void _onIncomingData(dynamic rawData) {
    try {
      final text = rawData.toString();
      // Handle potential multi-line batched frames
      final lines = text.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parsed = jsonDecode(trimmed) as Map<String, dynamic>;

        _handleInternalProtocolMessage(parsed);
        _messageController.add(parsed);
      }
    } catch (e) {
      _messageController.add({'type': 'raw', 'content': rawData.toString()});
    }
  }

  void _handleInternalProtocolMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    // 1. Connection acknowledgement
    if (type == 'connection_ack' || type == 'socket_connected') {
      _reconnectAttempts = 0;
      _setConnectionState(SocketConnectionState.connected);

      final payload = msg['payload'] as Map<String, dynamic>?;
      if (payload != null && payload['online_user_ids'] is List) {
        final ids = (payload['online_user_ids'] as List)
            .map((e) => (e as num).toInt())
            .toSet();
        onlineUserIdsNotifier.value = ids;
      }
      return;
    }

    // 2. Initial snapshot of all online users
    if (type == 'online_users_snapshot') {
      final payload = msg['payload'] as Map<String, dynamic>?;
      if (payload != null && payload['online_user_ids'] is List) {
        final ids = (payload['online_user_ids'] as List)
            .map((e) => (e as num).toInt())
            .toSet();
        onlineUserIdsNotifier.value = ids;
        if (kDebugMode) {
          print('[WS] Received online snapshot: ${ids.length} users online');
        }
      }
      _setConnectionState(SocketConnectionState.connected);
      return;
    }

    // 3. Dynamic presence update (user came online or went offline)
    if (type == 'user_status') {
      final payload = msg['payload'] as Map<String, dynamic>?;
      final userId = (payload?['user_id'] as num?)?.toInt() ??
          (msg['sender_id'] as num?)?.toInt();
      final isOnline = payload?['is_online'] == true || msg['is_online'] == true;

      if (userId != null && userId > 0) {
        final updated = Set<int>.from(onlineUserIdsNotifier.value);
        if (isOnline) {
          updated.add(userId);
        } else {
          updated.remove(userId);
        }
        onlineUserIdsNotifier.value = updated;
        if (kDebugMode) {
          print('[WS] User $userId is now ${isOnline ? 'ONLINE' : 'OFFLINE'}');
        }
      }
      return;
    }

    // 4. Pong heartbeat response
    if (type == 'pong') {
      if (state != SocketConnectionState.connected) {
        _reconnectAttempts = 0;
        _setConnectionState(SocketConnectionState.connected);
      }
      return;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastMessageReceivedAt = DateTime.now();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_channel == null || _isExplicitDisconnect) {
        timer.cancel();
        return;
      }

      // Check for connection stall (no message received in 50 seconds)
      if (_lastMessageReceivedAt != null &&
          DateTime.now().difference(_lastMessageReceivedAt!) >
              const Duration(seconds: 50)) {
        if (kDebugMode) {
          print('[WS] Heartbeat timeout. Dropping connection to reconnect...');
        }
        _handleDisconnect();
        return;
      }

      // Send ping frame to keep socket active
      try {
        _channel!.sink.add(jsonEncode({
          'type': 'ping',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }));
      } catch (_) {
        _handleDisconnect();
      }
    });
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _channel = null;

    if (_isExplicitDisconnect) {
      _setConnectionState(SocketConnectionState.disconnected);
      return;
    }

    _reconnectAttempts++;
    _setConnectionState(SocketConnectionState.reconnecting);

    // Exponential backoff: 1s, 2s, 4s, capped at 8s
    final delaySeconds = (_reconnectAttempts == 1)
        ? 1
        : (_reconnectAttempts == 2)
            ? 2
            : (_reconnectAttempts == 3)
                ? 4
                : 8;

    if (kDebugMode) {
      print(
          '[WS] Will attempt reconnection in ${delaySeconds}s (attempt $_reconnectAttempts)...');
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isExplicitDisconnect) {
        connect();
      }
    });
  }

  void _setConnectionState(SocketConnectionState nextState) {
    if (connectionStateNotifier.value != nextState) {
      connectionStateNotifier.value = nextState;
      if (kDebugMode) {
        print('[WS] Connection state changed: $nextState');
      }
      _messageController.add({
        'type': 'connection_state_changed',
        'status': nextState.name,
      });
    }
  }

  void sendMessage(String content) {
    if (_channel != null && isConnected) {
      final msg = jsonEncode({
        'type': 'chat_message',
        'content': content,
      });
      _channel!.sink.add(msg);
    }
  }

  void sendDirectMessage({
    required int receiverId,
    required String content,
    String mediaType = 'text',
    String? mediaUrl,
    String? forwardFrom,
  }) {
    if (_channel != null && isConnected) {
      final payload = <String, dynamic>{
        'type': 'chat_message',
        'receiver_id': receiverId,
        'content': content,
        'media_type': mediaType,
      };
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        payload['media_url'] = mediaUrl;
      }
      if (forwardFrom != null && forwardFrom.isNotEmpty) {
        payload['forward_from'] = forwardFrom;
      }
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendReadReceipt(int originalSenderId, {int? messageId}) {
    if (_channel != null && isConnected) {
      final payload = <String, dynamic>{
        'type': 'read_receipt',
        'receiver_id': originalSenderId,
      };
      if (messageId != null && messageId > 0) {
        payload['id'] = messageId;
        payload['message_id'] = messageId;
      }
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendGroupReadReceipt({required int groupId, int? messageId}) {
    if (_channel != null && isConnected) {
      final payload = <String, dynamic>{
        'type': 'group_read',
        'group_id': groupId,
      };
      if (messageId != null && messageId > 0) {
        payload['id'] = messageId;
        payload['message_id'] = messageId;
      }
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendReaction({
    required int messageId,
    required int receiverId,
    required String emoji,
    required String reactions,
  }) {
    if (_channel != null && isConnected) {
      _channel!.sink.add(jsonEncode({
        'type': 'message_reaction',
        'id': messageId,
        'receiver_id': receiverId,
        'reactions': reactions,
        'payload': {
          'message_id': messageId,
          'emoji': emoji,
          'reactions': reactions,
        },
      }));
    }
  }

  void sendDeleteMessage({
    required int messageId,
    required int receiverId,
  }) {
    if (_channel != null && isConnected) {
      _channel!.sink.add(jsonEncode({
        'type': 'message_deleted',
        'id': messageId,
        'receiver_id': receiverId,
        'payload': {
          'message_id': messageId,
        },
      }));
    }
  }

  void sendTyping({
    required int receiverId,
    required bool isTyping,
  }) {
    if (_channel != null && isConnected) {
      _channel!.sink.add(jsonEncode({
        'type': 'typing',
        'receiver_id': receiverId,
        'is_typing': isTyping,
      }));
    }
  }

  void sendGroupMessage({
    required int groupId,
    required String content,
    String mediaType = 'text',
    String? mediaUrl,
    String? forwardFrom,
  }) {
    if (_channel != null && isConnected) {
      final payload = <String, dynamic>{
        'type': 'group_message',
        'group_id': groupId,
        'content': content,
        'media_type': mediaType,
      };
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        payload['media_url'] = mediaUrl;
      }
      if (forwardFrom != null && forwardFrom.isNotEmpty) {
        payload['forward_from'] = forwardFrom;
      }
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendGroupTyping({
    required int groupId,
    required bool isTyping,
  }) {
    if (_channel != null && isConnected) {
      _channel!.sink.add(jsonEncode({
        'type': 'group_typing',
        'group_id': groupId,
        'is_typing': isTyping,
      }));
    }
  }

  void disconnect() {
    _isExplicitDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    onlineUserIdsNotifier.value = <int>{};
    _setConnectionState(SocketConnectionState.disconnected);
  }
}
