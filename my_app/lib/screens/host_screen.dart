import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/lan_network_service.dart';

class HostScreen extends StatefulWidget {
  final VoidCallback onPlayerJoined;
  final VoidCallback onBackPressed;

  const HostScreen({
    Key? key,
    required this.onPlayerJoined,
    required this.onBackPressed,
  }) : super(key: key);

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final LANNetworkService _net = LANNetworkService();
  String? _ip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = await _net.startHost();
    _net.onPlayerJoined = () {
      Navigator.push(context, MaterialPageRoute(builder: (c) => _getGameScreen()));
    };

    setState(() {
      _ip = _net.localIp;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _net.stop();
    super.dispose();
  }

  Widget _getGameScreen() {
    return GameScreenHost(net: _net);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Your IP:', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 10),
                  Text(_ip ?? '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _ip ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                    },
                    child: const Text('Copy IP'),
                  ),
                  const SizedBox(height: 20),
                  const Text('Waiting for player...'),
                ],
              ),
      ),
    );
  }
}

class GameScreenHost extends StatefulWidget {
  final LANNetworkService net;
  const GameScreenHost({Key? key, required this.net}) : super(key: key);
  @override
  State<GameScreenHost> createState() => _GameScreenHostState();
}

class _GameScreenHostState extends State<GameScreenHost> {
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
      setState(() => _msgs.add('Opponent: $text'));
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
