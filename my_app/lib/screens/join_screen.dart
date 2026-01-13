import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/lan_network_service.dart';

class JoinScreen extends StatefulWidget {
  final VoidCallback onConnected;
  final VoidCallback onBackPressed;
  final LANNetworkService networkService;

  const JoinScreen({
    Key? key,
    required this.onConnected,
    required this.onBackPressed,
    required this.networkService,
  }) : super(key: key);

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final TextEditingController _ipCtrl = TextEditingController();
  bool _connecting = false;
  String _error = '';

  Future<void> _connect() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _error = 'Enter IP');
      return;
    }

    setState(() {
      _connecting = true;
      _error = '';
    });

    final ok = await widget.networkService.connectToHost(ip);
    if (ok && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => GameScreenJoin(net: widget.networkService),
        ),
      );
    } else if (mounted) {
      setState(() {
        _connecting = false;
        _error = 'Connection failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Enter Host IP:', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              TextField(
                controller: _ipCtrl,
                decoration: const InputDecoration(
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_error.isNotEmpty) ...[
                Text(_error, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
              ],
              ElevatedButton(
                onPressed: _connecting ? null : _connect,
                child: Text(_connecting ? 'Connecting...' : 'Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameScreenJoin extends StatefulWidget {
  final LANNetworkService net;
  const GameScreenJoin({Key? key, required this.net}) : super(key: key);
  @override
  State<GameScreenJoin> createState() => _GameScreenJoinState();
}

class _GameScreenJoinState extends State<GameScreenJoin> {
  final List<String> _msgs = [];
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.net.onMessage = (Map<String, dynamic> msg) {
      String text;
      if (msg.containsKey('player') && msg.containsKey('data')) {
        text = '${msg['player']}: ${msg['data']}';
      } else if (msg.containsKey('data')) {
        text = msg['data'].toString();
      } else {
        text = jsonEncode(msg);
      }
      setState(() => _msgs.add('Host: $text'));
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _msgs.length,
              itemBuilder: (c, i) => ListTile(title: Text(_msgs[i])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _ctrl)),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    widget.net.send(_ctrl.text);
                    setState(() => _msgs.add('You: ${_ctrl.text}'));
                    _ctrl.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
