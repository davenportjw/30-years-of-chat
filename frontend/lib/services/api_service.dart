import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/chat_models.dart';
import '../models/era_architecture_models.dart';

class ApiService {
  late final String baseUrl;
  late final String wsUrl;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  // Stored callbacks for resilient auto-reconnect
  Function(Message)? _onNewMessage;
  Function(Map<String, dynamic>)? _onTyping;
  Function()? _onSeedReset;
  Function(PacingMode)? _onPacingUpdated;
  Function(AgentPresence)? _onPresenceUpdated;
  Function(MemoryBuffer)? _onBufferEvicted;
  Function(ConsolidationReport)? _onConsolidationCompleted;
  Function(PrivateScratchpad)? _onScratchpadUpdated;
  Function(TelemetrySpan)? _onMemoryTelemetry;

  ApiService({String? overrideUrl}) {
    if (overrideUrl != null && overrideUrl.isNotEmpty) {
      baseUrl = overrideUrl;
      wsUrl = '${overrideUrl.replaceFirst('http', 'ws')}/ws';
    } else if (kIsWeb) {
      // In Flutter Web, derive URL from current browser window origin if available
      final uri = Uri.base;
      if (uri.host.isNotEmpty && uri.port != 0 && uri.port != 80 && uri.port != 443) {
        // Dev server or specific port: connect to backend port 8080
        baseUrl = '${uri.scheme}://${uri.host}:8080';
        final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
        wsUrl = '$wsScheme://${uri.host}:8080/ws';
      } else if (uri.host.isNotEmpty) {
        // Cloud Run production single-container deployment
        baseUrl = '${uri.scheme}://${uri.host}';
        final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
        wsUrl = '$wsScheme://${uri.host}/ws';
      } else {
        baseUrl = 'http://localhost:8080';
        wsUrl = 'ws://localhost:8080/ws';
      }
    } else {
      baseUrl = 'http://localhost:8080';
      wsUrl = 'ws://localhost:8080/ws';
    }
  }

  Future<List<Channel>> fetchChannels() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/channels'));
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((c) => Channel.fromJson(c)).toList();
    }
    throw Exception('Failed to load channels: ${resp.statusCode}');
  }

  Future<List<Message>> fetchMessages(String channelId, {String? threadId}) async {
    var url = '$baseUrl/api/channels/$channelId/messages?limit=60';
    if (threadId != null && threadId.isNotEmpty) {
      url += '&thread_id=$threadId';
    }
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((m) => Message.fromJson(m)).toList();
    }
    throw Exception('Failed to load messages: ${resp.statusCode}');
  }

  Future<Message> sendMessage(String channelId, String content, {String? threadId, String? senderName}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/channels/$channelId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': content,
        'thread_id': threadId ?? '',
        'sender_name': senderName ?? 'Jason Davenport',
      }),
    );
    if (resp.statusCode == 201) {
      return Message.fromJson(jsonDecode(resp.body));
    }
    throw Exception('Failed to send message: ${resp.statusCode}');
  }

  Future<Message> injectEvent(String channelId, String title, String details, {String? threadId}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/channels/$channelId/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'details': details,
        'thread_id': threadId ?? '',
      }),
    );
    if (resp.statusCode == 201) {
      return Message.fromJson(jsonDecode(resp.body));
    }
    throw Exception('Failed to inject event: ${resp.statusCode}');
  }

  Future<List<Era>> fetchEras() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/eras'));
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => Era.fromJson(e)).toList();
    }
    throw Exception('Failed to load eras: ${resp.statusCode}');
  }

  Future<List<AgentPresence>> fetchPresences() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/presence'));
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((p) => AgentPresence.fromJson(p)).toList();
    }
    throw Exception('Failed to load agent presences: ${resp.statusCode}');
  }

  Future<void> updatePresence(AgentPresence presence) async {
    await http.post(
      Uri.parse('$baseUrl/api/presence'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(presence.toJson()),
    );
  }

  Future<MemoryBuffer> fetchBuffer(String channelId) async {
    final resp = await http.get(Uri.parse('$baseUrl/api/channels/$channelId/buffer'));
    if (resp.statusCode == 200) {
      return MemoryBuffer.fromJson(jsonDecode(resp.body));
    }
    throw Exception('Failed to load memory buffer: ${resp.statusCode}');
  }

  Future<ConsolidationReport> triggerConsolidation(String channelId) async {
    final resp = await http.post(Uri.parse('$baseUrl/api/channels/$channelId/consolidate'));
    if (resp.statusCode == 201) {
      return ConsolidationReport.fromJson(jsonDecode(resp.body));
    }
    throw Exception('Failed to trigger dreaming consolidation: ${resp.statusCode}');
  }

  Future<List<ConsolidationReport>> fetchConsolidationReports(String channelId) async {
    final resp = await http.get(Uri.parse('$baseUrl/api/channels/$channelId/reports'));
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((r) => ConsolidationReport.fromJson(r)).toList();
    }
    return [];
  }

  Future<PrivateScratchpad> fetchScratchpad(String agentId, String channelId) async {
    final resp = await http.get(Uri.parse('$baseUrl/api/scratchpads?agent_id=$agentId&channel_id=$channelId'));
    if (resp.statusCode == 200) {
      return PrivateScratchpad.fromJson(jsonDecode(resp.body));
    }
    throw Exception('Failed to load private scratchpad: ${resp.statusCode}');
  }

  Future<void> reseedData() async {
    final resp = await http.post(Uri.parse('$baseUrl/api/seed'));
    if (resp.statusCode != 200) {
      throw Exception('Failed to reseed: ${resp.statusCode}');
    }
  }

  Future<PacingMode> fetchPacing() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/pacing'));
    if (resp.statusCode == 200) {
      return PacingMode.fromJson(jsonDecode(resp.body));
    }
    return PacingMode(paused: false, intervalSeconds: 8);
  }

  Future<void> updatePacing(PacingMode pacing) async {
    await http.post(
      Uri.parse('$baseUrl/api/pacing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(pacing.toJson()),
    );
  }

  void connectWebSocket({
    required Function(Message) onNewMessage,
    required Function(Map<String, dynamic>) onTyping,
    required Function() onSeedReset,
    required Function(PacingMode) onPacingUpdated,
    Function(AgentPresence)? onPresenceUpdated,
    Function(MemoryBuffer)? onBufferEvicted,
    Function(ConsolidationReport)? onConsolidationCompleted,
    Function(PrivateScratchpad)? onScratchpadUpdated,
    Function(TelemetrySpan)? onMemoryTelemetry,
  }) {
    _onNewMessage = onNewMessage;
    _onTyping = onTyping;
    _onSeedReset = onSeedReset;
    _onPacingUpdated = onPacingUpdated;
    _onPresenceUpdated = onPresenceUpdated;
    _onBufferEvicted = onBufferEvicted;
    _onConsolidationCompleted = onConsolidationCompleted;
    _onScratchpadUpdated = onScratchpadUpdated;
    _onMemoryTelemetry = onMemoryTelemetry;

    _startWebSocketConnection();
  }

  void _startWebSocketConnection() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();

    try {
      _wsSubscription?.cancel();
      _wsChannel?.sink.close();
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsSubscription = _wsChannel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> msg = jsonDecode(data);
            final type = msg['type'];
            final payload = msg['payload'];

            if (type == 'new_message' && _onNewMessage != null) {
              _onNewMessage!(Message.fromJson(payload));
            } else if (type == 'agent_typing' && _onTyping != null) {
              _onTyping!(payload as Map<String, dynamic>);
            } else if (type == 'seed_reset' && _onSeedReset != null) {
              _onSeedReset!();
            } else if (type == 'pacing_updated' && _onPacingUpdated != null) {
              _onPacingUpdated!(PacingMode.fromJson(payload));
            } else if (type == 'presence_updated' && _onPresenceUpdated != null) {
              _onPresenceUpdated!(AgentPresence.fromJson(payload));
            } else if (type == 'buffer_evicted' && _onBufferEvicted != null) {
              _onBufferEvicted!(MemoryBuffer.fromJson(payload));
            } else if (type == 'consolidation_completed' && _onConsolidationCompleted != null) {
              _onConsolidationCompleted!(ConsolidationReport.fromJson(payload));
            } else if (type == 'scratchpad_updated' && _onScratchpadUpdated != null) {
              _onScratchpadUpdated!(PrivateScratchpad.fromJson(payload));
            } else if (type == 'memory_telemetry' && _onMemoryTelemetry != null) {
              _onMemoryTelemetry!(TelemetrySpan.fromJson(payload as Map<String, dynamic>));
            }
          } catch (e) {
            debugPrint('Error parsing WS message: $e');
          }
        },
        onError: (err) {
          debugPrint('WebSocket error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDisposed) {
        _startWebSocketConnection();
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
  }
}
