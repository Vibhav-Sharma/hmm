import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:get_ip_address/get_ip_address.dart';
import 'package:flutter/material.dart';

/// Callback type for receiving messages from the network
typedef MessageCallback = void Function(String message);

/// Callback type for connection state changes
typedef ConnectionStateCallback = void Function(bool isConnected);

/// Manages LAN networking for 2-player game hub
/// Supports both Host (server) and Client modes
class LANNetworkService {
  // Server components
  HttpServer? _server;
  final List<WebSocket> _connectedClients = [];

  // Client components
  WebSocketChannel? _clientChannel;

  // State management
  bool _isHost = false;
  bool _isConnected = false;
  String? _localIp;
  static const int defaultPort = 8888;

  // Callbacks
  MessageCallback? onMessageReceived;
  ConnectionStateCallback? onConnectionStateChanged;
  VoidCallback? onPlayerJoined;

  /// Get the current local IP address on the LAN
  Future<String?> getLocalIp() async {
    if (_localIp != null) return _localIp;

    try {
      final ip = IpAddress(type: RequestType.text);
      _localIp = await ip.getIpAddress();
      return _localIp;
    } catch (e) {
      print('Error getting IP: $e');
      return null;
    }
  }

  /// Start hosting a game server
  /// Returns the IP address where the server is running
  Future<String?> startHosting({int port = defaultPort}) async {
    try {
      _isHost = true;

      // Get local IP
      final ip = await getLocalIp();
      if (ip == null) {
        throw Exception('Could not determine local IP address');
      }

      // Start WebSocket server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Server started on $ip:$port');

      // Listen for WebSocket connections
      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((webSocket) {
            _handleClientConnection(webSocket);
          });
        }
      });

      _setConnectionState(true);
      return 'ws://$ip:$port';
    } catch (e) {
      print('Error starting host: $e');
      _setConnectionState(false);
      return null;
    }
  }

  /// Handle a new client connection on the server
  void _handleClientConnection(WebSocket clientSocket) {
    _connectedClients.add(clientSocket);
    print('Client connected. Total clients: ${_connectedClients.length}');

    // Notify host that a player joined
    onPlayerJoined?.call();

    // Listen to messages from this client
    clientSocket.listen(
      (message) {
        print('Server received: $message');
        // Broadcast message to all other connected clients
        _broadcastToClients(message, sender: clientSocket);
      },
      onError: (error) {
        print('Client error: $error');
        _connectedClients.remove(clientSocket);
      },
      onDone: () {
        print('Client disconnected');
        _connectedClients.remove(clientSocket);
      },
    );
  }

  /// Broadcast a message to all connected clients except the sender
  void _broadcastToClients(String message, {WebSocket? sender}) {
    for (var client in _connectedClients) {
      if (client != sender) {
        try {
          client.add(message);
        } catch (e) {
          print('Error sending to client: $e');
        }
      }
    }
  }

  /// Connect to a hosting game server
  Future<bool> connectToHost(String hostAddress, {int port = defaultPort}) async {
    try {
      final url = Uri.parse('ws://$hostAddress:$port');
      _clientChannel = WebSocketChannel.connect(url);

      // Wait for connection to be established
      await _clientChannel!.ready;
      print('Connected to host at $hostAddress:$port');

      _isHost = false;
      _setConnectionState(true);

      // Listen for messages from host/other player
      _clientChannel!.stream.listen(
        (message) {
          print('Client received: $message');
          onMessageReceived?.call(message);
        },
        onError: (error) {
          print('Connection error: $error');
          _setConnectionState(false);
        },
        onDone: () {
          print('Disconnected from host');
          _setConnectionState(false);
        },
      );

      return true;
    } catch (e) {
      print('Error connecting to host: $e');
      _setConnectionState(false);
      return false;
    }
  }

  /// Send a message to the other player(s)
  void sendMessage(String message) {
    try {
      if (_isHost) {
        // If hosting, broadcast to all clients
        _broadcastToClients(message);
      } else if (_clientChannel != null) {
        // If client, send to host/server
        _clientChannel!.sink.add(message);
      }
      print('Sent: $message');
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  /// Send a game move with structured data
  void sendGameMove(String playerName, String moveData) {
    final messageJson = jsonEncode({
      'type': 'move',
      'player': playerName,
      'data': moveData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    sendMessage(messageJson);
  }

  /// Send a player joined notification
  void broadcastPlayerJoined(String playerName) {
    final messageJson = jsonEncode({
      'type': 'playerJoined',
      'player': playerName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    sendMessage(messageJson);
  }

  /// Send turn information
  void sendTurnInfo(String currentPlayer) {
    final messageJson = jsonEncode({
      'type': 'turn',
      'currentPlayer': currentPlayer,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    sendMessage(messageJson);
  }

  /// Stop hosting the server
  Future<void> stopHosting() async {
    try {
      // Close all client connections
      for (var client in _connectedClients) {
        await client.close(status.goingAway);
      }
      _connectedClients.clear();

      // Stop the server
      await _server?.close();
      _server = null;

      _isHost = false;
      _setConnectionState(false);
      print('Host stopped');
    } catch (e) {
      print('Error stopping host: $e');
    }
  }

  /// Disconnect from the host
  Future<void> disconnect() async {
    try {
      await _clientChannel?.sink.close(status.goingAway);
      _clientChannel = null;
      _isConnected = false;
      _setConnectionState(false);
      print('Disconnected from host');
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  /// Get connection status
  bool get isConnected => _isConnected;
  bool get isHost => _isHost;
  int get connectedClientCount => _connectedClients.length;

  /// Update connection state and notify listeners
  void _setConnectionState(bool connected) {
    _isConnected = connected;
    onConnectionStateChanged?.call(connected);
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_isHost) {
      await stopHosting();
    } else {
      await disconnect();
    }
  }
}
