import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/lan_network_service.dart';

/// Reaction Game
/// - Host triggers START (random delay 1-3s) and broadcasts to client
/// - After delay both sides show TAP NOW
/// - First to tap sends timestamp via LAN
/// - Host decides winner and broadcasts result

class ReactionGameScreen extends StatefulWidget {
  final LANNetworkService net;
  final String player; // 'host' or 'client'

  const ReactionGameScreen({Key? key, required this.net, required this.player}) : super(key: key);

  @override
  State<ReactionGameScreen> createState() => _ReactionGameScreenState();
}

class _ReactionGameScreenState extends State<ReactionGameScreen> {
  final Random _rnd = Random();
  String status = 'Idle';
  bool canTap = false;
  int? startTime;
  Map<String, int> taps = {}; // player -> timestamp
  Timer? _delayedTimer;
  Timer? _hostDecideTimer;

  @override
  void initState() {
    super.initState();
    widget.net.onMessage = (Map<String, dynamic> msg) {
      try {
        if (msg['game'] != 'reaction') return;
        final t = msg['type'];
        final p = msg['player'] as String?;
        final data = msg['data'] as Map<String, dynamic>?;
        if (t == 'start') {
          final delay = (data?['delay'] as int?) ?? 0;
          _onStartReceived(delay);
        } else if (t == 'tap' && p != null) {
          final time = data?['time'] as int?;
          if (time != null) _onTapReceived(p, time);
        } else if (t == 'result') {
          final winner = data?['winner'] as String?;
          setState(() {
            status = winner == null ? 'No result' : 'Winner: $winner';
            canTap = false;
          });
        }
      } catch (e) {
        print('[REACTION] Error: $e');
      }
    };
  }

  void _onStartReceived(int delayMs) {
    setState(() {
      status = 'Get Ready...';
      canTap = false;
      taps.clear();
    });
    _delayedTimer?.cancel();
    _delayedTimer = Timer(Duration(milliseconds: delayMs), () {
      setState(() {
        status = 'TAP NOW!';
        canTap = true;
        startTime = DateTime.now().millisecondsSinceEpoch;
      });
    });
  }

  void _onTapReceived(String player, int time) {
    taps[player] = time;
    // If host, decide winner when reasonable
    if (widget.player == 'host') {
      if (taps.length == 2) {
        _decideAndBroadcastWinner();
      } else {
        // wait a short window for other tap
        _hostDecideTimer?.cancel();
        _hostDecideTimer = Timer(const Duration(milliseconds: 300), () {
          _decideAndBroadcastWinner();
        });
      }
    } else {
      // client: wait for result from host
      // we can show temporary message
      setState(() => status = 'Opponent tapped');
    }
  }

  void _decideAndBroadcastWinner() {
    _hostDecideTimer?.cancel();
    final hostTime = taps['host'];
    final clientTime = taps['client'];
    String winner;
    if (hostTime != null && clientTime != null) {
      if (hostTime < clientTime) winner = 'host'; else if (clientTime < hostTime) winner = 'client'; else winner = 'draw';
    } else if (hostTime != null) {
      winner = 'host';
    } else if (clientTime != null) {
      winner = 'client';
    } else {
      winner = 'draw';
    }

    final msg = {
      'game': 'reaction',
      'type': 'result',
      'player': 'host',
      'data': {'winner': winner, 'times': taps}
    };
    widget.net.send(jsonEncode(msg));
    setState(() {
      status = 'Winner: $winner';
      canTap = false;
    });
  }

  void _startAsHost() {
    if (widget.player != 'host') return;
    final delayMs = 1000 + _rnd.nextInt(2000); // 1-3s
    final msg = {
      'game': 'reaction',
      'type': 'start',
      'player': 'host',
      'data': {'delay': delayMs}
    };
    widget.net.send(jsonEncode(msg));
    // Also start locally
    _onStartReceived(delayMs);
  }

  void _tap() {
    if (!canTap) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    canTap = false; // disable immediate re-tap
    final msg = {
      'game': 'reaction',
      'type': 'tap',
      'player': widget.player,
      'data': {'time': now}
    };
    widget.net.send(jsonEncode(msg));
    setState(() {
      status = 'You tapped';
    });
    // if host tapped early and client already tapped, handle locally
    if (widget.player == 'host') {
      taps['host'] = now;
      if (taps.length == 2) _decideAndBroadcastWinner();
    }
  }

  void _reset() {
    _delayedTimer?.cancel();
    _hostDecideTimer?.cancel();
    taps.clear();
    startTime = null;
    setState(() {
      status = 'Idle';
      canTap = false;
    });
  }

  @override
  void dispose() {
    _delayedTimer?.cancel();
    _hostDecideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reaction Game'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reset),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Role: ${widget.player}'),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (widget.player == 'host') ...[
              ElevatedButton(onPressed: _startAsHost, child: const Text('START (Host)')),
            ],
            const SizedBox(height: 20),
            ElevatedButton(onPressed: canTap ? _tap : null, child: const Text('TAP')),
          ],
        ),
      ),
    );
  }
}
