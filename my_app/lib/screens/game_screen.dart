import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/lan_network_service.dart';

/// Game screen where players interact in real-time
/// Syncs player moves and turn information
class GameScreen extends StatefulWidget {
  final LANNetworkService networkService;
  final String playerName;
  final VoidCallback onGameEnd;

  const GameScreen({
    Key? key,
    required this.networkService,
    required this.playerName,
    required this.onGameEnd,
  }) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<String> _messages = [];
  String _currentTurn = 'Player 1';
  String _opponentMove = 'Waiting...';
  final TextEditingController _moveController = TextEditingController();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _setupNetworkListeners();
    _initializeGame();
  }

  /// Set up network message listeners
  void _setupNetworkListeners() {
    // Listen for messages from the other player
    widget.networkService.onMessageReceived = (String message) {
      _handleReceivedMessage(message);
    };

    // Listen for connection state changes
    widget.networkService.onConnectionStateChanged = (bool connected) {
      setState(() {
        _isConnected = connected;
      });

      if (!connected) {
        _addSystemMessage('Opponent disconnected!');
      }
    };
  }

  /// Initialize game and notify opponent
  void _initializeGame() {
    setState(() {
      _isConnected = widget.networkService.isConnected;
    });

    // Notify opponent that you've joined
    widget.networkService.broadcastPlayerJoined(widget.playerName);
    _addSystemMessage('You joined the game!');
  }

  /// Handle received messages from network
  void _handleReceivedMessage(String message) {
    try {
      // Try to parse as JSON
      final Map<String, dynamic> data = jsonDecode(message);

      switch (data['type']) {
        case 'move':
          setState(() {
            _opponentMove = '${data['player']}: ${data['data']}';
          });
          _addSystemMessage(
              '${data['player']} played: ${data['data']}');
          break;

        case 'playerJoined':
          _addSystemMessage('${data['player']} joined the game!');
          break;

        case 'turn':
          setState(() {
            _currentTurn = data['currentPlayer'];
          });
          _addSystemMessage('Current turn: ${data['currentPlayer']}');
          break;

        default:
          _addSystemMessage('Opponent: ${data['type']}');
      }
    } catch (e) {
      // If not JSON, treat as plain text message
      _addSystemMessage('Opponent: $message');
    }
  }

  /// Send a game move to the opponent
  void _sendMove() {
    final move = _moveController.text.trim();
    if (move.isEmpty) return;

    // Send move through network
    widget.networkService.sendGameMove(widget.playerName, move);

    // Add to local message log
    _addSystemMessage('You played: $move');
    _moveController.clear();
  }

  /// Add a system message to the message log
  void _addSystemMessage(String message) {
    setState(() {
      _messages.add(
        '${DateTime.now().hour.toString().padLeft(2, '0')}:'
        '${DateTime.now().minute.toString().padLeft(2, '0')} - $message',
      );
    });
  }

  /// End game and return to home
  void _endGame() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('End Game?'),
        content: const Text('Are you sure you want to leave the game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onGameEnd();
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _endGame();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.playerName} - ${_isConnected ? 'Connected' : 'Disconnected'}',
          ),
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _endGame,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isConnected ? 'Online' : 'Offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Game Status Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Current Turn',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentTurn,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Opponent\'s Last Move',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _opponentMove,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Message Log
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Waiting for messages...',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final isPlayerMove =
                                _messages[index].contains('You played:');
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPlayerMove
                                      ? Colors.green.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _messages[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isPlayerMove
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Input Area
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Move:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _moveController,
                            enabled: _isConnected,
                            decoration: InputDecoration(
                              hintText: 'Enter your move...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onSubmitted: (_) => _sendMove(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isConnected ? _sendMove : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
