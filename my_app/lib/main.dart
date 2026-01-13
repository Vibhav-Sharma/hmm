import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/host_screen.dart';
import 'screens/join_screen.dart';
import 'screens/game_screen.dart';
import 'services/lan_network_service.dart';

// Enum for screen navigation
enum GameHubScreen { home, host, join, game }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAN Game Hub',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const GameHubApp(),
    );
  }
}

/// Main app controller that manages navigation between screens
class GameHubApp extends StatefulWidget {
  const GameHubApp({super.key});

  @override
  State<GameHubApp> createState() => _GameHubAppState();
}

class _GameHubAppState extends State<GameHubApp> {
  GameHubScreen _currentScreen = GameHubScreen.home;
  late LANNetworkService _networkService;
  String _playerName = 'Player 1';

  @override
  void initState() {
    super.initState();
    _networkService = LANNetworkService();
  }

  /// Navigate to home screen
  void _goHome() {
    setState(() {
      _currentScreen = GameHubScreen.home;
    });
  }

  /// Navigate to host screen
  void _goHost() {
    setState(() {
      _currentScreen = GameHubScreen.host;
    });
  }

  /// Navigate to join screen
  void _goJoin() {
    setState(() {
      _currentScreen = GameHubScreen.join;
    });
  }

  /// Navigate to game screen
  void _goGame() {
    setState(() {
      _currentScreen = GameHubScreen.game;
    });
  }

  @override
  void dispose() {
    _networkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build appropriate screen based on current state
    switch (_currentScreen) {
      case GameHubScreen.home:
        return HomeScreen(
          onHostTap: _goHost,
          onJoinTap: _goJoin,
        );

      case GameHubScreen.host:
        return HostScreen(
          onPlayerJoined: _goGame,
          onBackPressed: _goHome,
        );

      case GameHubScreen.join:
        return JoinScreen(
          networkService: _networkService,
          onConnected: _goGame,
          onBackPressed: _goHome,
        );

      case GameHubScreen.game:
        return GameScreen(
          networkService: _networkService,
          playerName: _playerName,
          onGameEnd: _goHome,
        );
    }
  }
}
