import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// LAN networking service (MVP, reliable on Android physical devices)
/// - Uses dart:io for server and client WebSockets
/// - JSON-based messages only
/// - Explicit connection state and callbacks
/// - Connection timeout and error callbacks

enum ConnectionState { idle, hosting, connected, disconnected }

class LANNetworkService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  WebSocket? _clientSocket;

  ConnectionState state = ConnectionState.idle;

  // Callbacks
  void Function(Map<String, dynamic> message)? onMessage;
  void Function(ConnectionState state)? onStateChanged;
  void Function(Object error)? onError;
  void Function()? onPlayerJoined;

  // Last detected local IPv4
  String? localIp;

  // Default port
  final int port;

  LANNetworkService({this.port = 8888});

  // -----------------
  // Utility helpers
  // -----------------

  void _updateState(ConnectionState s) {
    state = s;
    print('[LAN] State -> $s');
    try {
      onStateChanged?.call(s);
    } catch (e) {}
  }

  Map<String, dynamic>? _tryParseJson(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'type': 'raw', 'data': decoded};
    } catch (e) {
      print('[LAN] Invalid JSON: $e');
      return null;
    }
  }

  // -----------------
  // IP detection
  // -----------------

  /// Detects the local IPv4 address on the device on the LAN.
  /// Tries to pick a private RFC1918 address (192.168.x.x, 10.x.x.x, 172.16-31.x.x).
  Future<String?> getLocalIp() async {
    if (localIp != null) return localIp;
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Prefer common private ranges
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final a = addr.address;
          if (a.startsWith('192.168.') || a.startsWith('10.') || a.startsWith('172.')) {
            localIp = a;
            print('[LAN] Local IP detected: $localIp');
            return localIp;
          }
        }
      }

      // Fallback: any non-loopback IPv4
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final a = addr.address;
          if (!addr.isLoopback) {
            localIp = a;
            print('[LAN] Local IP detected (fallback): $localIp');
            return localIp;
          }
        }
      }

      print('[LAN] No local IPv4 address found');
      return null;
    } catch (e) {
      print('[LAN] Error detecting local IP: $e');
      onError?.call(e);
      return null;
    }
  }

  // -----------------
  // Hosting (server)
  // -----------------

  /// Start the WebSocket server and begin listening for client connections.
  /// Returns the ws:// URL that clients can connect to, or null on failure.
  Future<String?> startHost() async {
    _updateState(ConnectionState.hosting);
    try {
      final ip = await getLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('[LAN] Server listening on 0.0.0.0:$port');

      _server!.listen((HttpRequest request) async {
        // Only accept WebSocket upgrade requests
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..write('WebSocket endpoint')
            ..close();
          return;
        }

        try {
          final remoteAddress = request.connectionInfo?.remoteAddress.address;
          final ws = await WebSocketTransformer.upgrade(request);
          print('[LAN] Client connected: $remoteAddress');

          // Add to client list
          _clients.add(ws);
          try {
            onPlayerJoined?.call();
          } catch (e) {}

          // Listen for messages from this client
          ws.listen((dynamic data) {
            print('[LAN] Server received from $remoteAddress: $data');
            if (data is String) {
              final parsed = _tryParseJson(data);
              if (parsed != null) {
                // Notify host app about incoming message
                try {
                  onMessage?.call(parsed);
                } catch (e) {}

                // Broadcast to other clients (not back to sender)
                final encoded = jsonEncode(parsed);
                for (final c in List<WebSocket>.from(_clients)) {
                  if (identical(c, ws)) continue;
                  try {
                    c.add(encoded);
                  } catch (e) {
                    print('[LAN] Failed to send to client: $e');
                  }
                }
              }
            }
          }, onDone: () {
            print('[LAN] Client disconnected: $remoteAddress');
            _clients.remove(ws);
            if (_clients.isEmpty) {
              // keep hosting but notify state
              _updateState(ConnectionState.hosting);
            }
          }, onError: (err) {
            print('[LAN] Client error from $remoteAddress: $err');
            _clients.remove(ws);
            onError?.call(err);
          });
        } catch (e) {
          print('[LAN] Error during WebSocket upgrade: $e');
          onError?.call(e);
        }
      });

      final url = (localIp != null) ? 'ws://$localIp:$port' : 'ws://<your-ip>:$port';
      print('[LAN] Host ready at $url');
      _updateState(ConnectionState.hosting);
      return url;
    } catch (e) {
      print('[LAN] Failed to start host: $e');
      onError?.call(e);
      _updateState(ConnectionState.disconnected);
      return null;
    }
  }

  // -----------------
  // Client connect
  // -----------------

  /// Connect to a host at given IP and port. Returns true on success.
  /// Times out after [timeoutSecs] seconds.
  Future<bool> connectToHost(String hostIp, {int timeoutSecs = 5}) async {
    _updateState(ConnectionState.disconnected);
    final uri = 'ws://$hostIp:$port';
    print('[LAN] Attempting to connect to $uri');

    try {
      final sock = await WebSocket.connect(uri).timeout(Duration(seconds: timeoutSecs));
      _clientSocket = sock;
      print('[LAN] Connected to host');
      _updateState(ConnectionState.connected);

      // Listen for messages from host / other clients (routed by server)
      _clientSocket!.listen((dynamic data) {
        print('[LAN] Client received: $data');
        if (data is String) {
          final parsed = _tryParseJson(data);
          if (parsed != null) {
            try {
              onMessage?.call(parsed);
            } catch (e) {}
          }
        }
      }, onDone: () {
        print('[LAN] Disconnected from host');
        _updateState(ConnectionState.disconnected);
      }, onError: (err) {
        print('[LAN] Client socket error: $err');
        onError?.call(err);
        _updateState(ConnectionState.disconnected);
      });

      return true;
    } catch (e) {
      print('[LAN] Failed to connect: $e');
      onError?.call(e);
      _updateState(ConnectionState.disconnected);
      return false;
    }
  }

  // -----------------
  // Sending messages
  // -----------------

  /// Sends a JSON-serializable message (Map) from either host or client.
  /// If hosting: broadcast to all connected clients and notify local app via onMessage.
  /// If connected as client: send to host server.
  void sendMessage(Map<String, dynamic> message) {
    final encoded = jsonEncode(message);
    print('[LAN] Sending: $encoded');

    if (state == ConnectionState.hosting) {
      // Host broadcasts to all clients
      for (final c in List<WebSocket>.from(_clients)) {
        try {
          c.add(encoded);
        } catch (e) {
          print('[LAN] Failed to send to client: $e');
          onError?.call(e);
        }
      }

      // Also notify the host app (host is a player too)
      try {
        onMessage?.call(message);
      } catch (e) {}

    } else if (state == ConnectionState.connected && _clientSocket != null) {
      try {
        _clientSocket!.add(encoded);
      } catch (e) {
        print('[LAN] Failed to send to host: $e');
        onError?.call(e);
      }
    } else {
      print('[LAN] Cannot send message - not connected or hosting');
      onError?.call('Not connected');
    }
  }

  /// Compatibility helper: accept plain text or JSON string and send
  void send(String raw) {
    try {
      // Try parse as JSON map first
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        sendMessage(decoded);
        return;
      }
      // If JSON decode is not a map, wrap it
      sendMessage({'type': 'raw', 'data': decoded, 'timestamp': DateTime.now().millisecondsSinceEpoch});
    } catch (e) {
      // Not JSON - send as text payload
      sendMessage({'type': 'text', 'data': raw, 'timestamp': DateTime.now().millisecondsSinceEpoch});
    }
  }

  /// Compatibility helper: stop host or disconnect client depending on mode
  Future<void> stop() async {
    print('[LAN] stop() called - delegating to stopHost/disconnectClient');
    if (state == ConnectionState.hosting) {
      await stopHost();
    } else if (state == ConnectionState.connected) {
      await disconnectClient();
    } else {
      print('[LAN] stop() - nothing to stop (state=$state)');
    }
  }

  // -----------------
  // Stop / disconnect
  // -----------------

  /// Stops hosting and disconnects all clients
  Future<void> stopHost() async {
    try {
      print('[LAN] Stopping host');
      for (final c in List<WebSocket>.from(_clients)) {
        await c.close(WebSocketStatus.normalClosure);
      }
      _clients.clear();
      await _server?.close(force: true);
      _server = null;
      _updateState(ConnectionState.idle);
    } catch (e) {
      print('[LAN] Error stopping host: $e');
      onError?.call(e);
    }
  }

  /// Disconnect client from host
  Future<void> disconnectClient() async {
    try {
      print('[LAN] Disconnecting client');
      await _clientSocket?.close(WebSocketStatus.normalClosure);
      _clientSocket = null;
      _updateState(ConnectionState.idle);
    } catch (e) {
      print('[LAN] Error disconnecting client: $e');
      onError?.call(e);
    }
  }

  /// Full cleanup
  Future<void> dispose() async {
    await stopHost();
    await disconnectClient();
    _updateState(ConnectionState.idle);
  }
}

