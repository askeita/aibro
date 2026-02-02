import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';


/// Handles STOMP/WebSocket connection to the backend /ws endpoint and exposes
/// a stream of AI notifications for a given session.
class WebSocketService {
  StompClient? _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  final StreamController<Map<String, dynamic>> _aiController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Broadcast stream of AI notification messages for the connected session.
  Stream<Map<String, dynamic>> get aiMessages => _aiController.stream;

  /// Whether the underlying STOMP client is currently connected.
  bool get isConnected => _client?.connected ?? false;

  /// Establishes a WebSocket connection for the given [sessionId] and starts
  /// listening for AI notification messages.
  void connect(int sessionId) {
    if (_client != null && _client!.connected) {
      return;
    }

    _client = StompClient(
      config: StompConfig.sockJS(
        url: 'http://localhost:8080/ws',
        onConnect: (StompFrame frame) {
          _client?.subscribe(
            destination: '/topic/session/$sessionId/ai',
            callback: (StompFrame message) {
              final body = message.body;
              if (body == null || body.isEmpty) return;
              try {
                final data = jsonDecode(body) as Map<String, dynamic>;
                _aiController.add(data);
              } catch (_) {
                // Ignore malformed messages.
              }
            },
          );
        },
        onWebSocketError: (dynamic error) {
          // For now just print; can be improved with logging/snackbar.
          // ignore: avoid_print
          print('WebSocket error: $error');
        },
      ),
    )
      ..activate();
  }

  /// Closes the WebSocket connection and cancels any active subscriptions.
  void disconnect() {
    _subscription?.cancel();
    _client?.deactivate();
    _client = null;
  }

  /// Disposes of this service and its internal resources.
  void dispose() {
    disconnect();
    _aiController.close();
  }
}

