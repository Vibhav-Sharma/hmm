import 'package:flutter/material.dart';
import '../services/lan_network_service.dart';

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
  final TextEditingController _moveController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.networkService.onMessage = (Map<String, dynamic> msg) {
      String text;
      if (msg.containsKey('player') && msg.containsKey('data')) {
        text = '${msg['player']}: ${msg['data']}';
      } else if (msg.containsKey('data')) {
        text = msg['data'].toString();
      } else {
        text = msg.toString();
      }
      setState(() => _messages.add('Opponent: $text'));
    };
  }

  void _sendMove() {
    final move = _moveController.text.trim();
    if (move.isEmpty) return;
    
    widget.networkService.send(move);
    setState(() => _messages.add('You: $move'));
    _moveController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.playerName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (c, i) => ListTile(title: Text(_messages[i])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _moveController,
                    decoration: const InputDecoration(
                      hintText: 'Your move...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMove(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMove,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
