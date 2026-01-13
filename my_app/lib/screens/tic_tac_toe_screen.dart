import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/lan_network_service.dart';

/// Simple Tic Tac Toe (3x3) using LANNetworkService
/// - Host = 'host' (X) and starts the game
/// - Client = 'client' (O)
/// - Uses JSON messages sent via network.send(jsonEncode(...))
/// - Handles incoming messages via network.onMessage

class TicTacToeScreen extends StatefulWidget {
  final LANNetworkService net;
  final String player; // 'host' or 'client'

  const TicTacToeScreen({Key? key, required this.net, required this.player}) : super(key: key);

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  List<String> board = List<String>.filled(9, '');
  String currentTurn = 'host'; // host starts
  String status = '';

  @override
  void initState() {
    super.initState();
    status = 'Your symbol: ${symbolFor(widget.player)}';

    // Listen for moves from network
    widget.net.onMessage = (Map<String, dynamic> msg) {
      try {
        if (msg['game'] == 'tic_tac_toe' && msg['type'] == 'move') {
          final idx = (msg['data']?['index']) as int?;
          final from = msg['player'] as String?;
          if (idx != null && from != null) {
            _applyMoveFromNetwork(idx, from);
          }
        }
      } catch (e) {
        print('[TTT] Error handling message: $e');
      }
    };
  }

  String symbolFor(String player) => player == 'host' ? 'X' : 'O';

  void _applyMoveFromNetwork(int idx, String from) {
    // validate and apply
    if (idx < 0 || idx >= 9) return;
    if (board[idx].isNotEmpty) return; // already taken

    setState(() {
      board[idx] = symbolFor(from);
      currentTurn = (from == 'host') ? 'client' : 'host';
      status = 'Last move: ${from}';
    });
  }

  void _onCellTap(int idx) {
    if (board[idx].isNotEmpty) return;
    if (currentTurn != widget.player) return; // not your turn

    // make local move
    setState(() {
      board[idx] = symbolFor(widget.player);
      currentTurn = (widget.player == 'host') ? 'client' : 'host';
    });

    // send move via LAN as JSON
    final msg = {
      'game': 'tic_tac_toe',
      'type': 'move',
      'player': widget.player,
      'data': {'index': idx}
    };
    widget.net.send(jsonEncode(msg));
  }

  void _resetGame() {
    setState(() {
      board = List<String>.filled(9, '');
      currentTurn = 'host';
      status = 'Your symbol: ${symbolFor(widget.player)}';
    });
  }

  String? _checkWinner() {
    final lines = [
      [0,1,2], [3,4,5], [6,7,8],
      [0,3,6], [1,4,7], [2,5,8],
      [0,4,8], [2,4,6]
    ];
    for (final l in lines) {
      final a = board[l[0]];
      final b = board[l[1]];
      final c = board[l[2]];
      if (a.isNotEmpty && a == b && b == c) return a;
    }
    if (!board.contains('')) return 'draw';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final winner = _checkWinner();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic Tac Toe'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetGame),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text('Player: ${widget.player} (${symbolFor(widget.player)})'),
                const SizedBox(height: 6),
                Text('Current turn: $currentTurn'),
                const SizedBox(height: 6),
                Text(status),
                const SizedBox(height: 12),
                if (winner != null) ...[
                  Text(winner == 'draw' ? 'Draw!' : 'Winner: $winner', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(20),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: List.generate(9, (i) {
                return GestureDetector(
                  onTap: winner == null ? () => _onCellTap(i) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54),
                      color: Colors.grey[200],
                    ),
                    child: Center(
                      child: Text(board[i], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
