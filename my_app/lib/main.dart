import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/host_screen.dart';
import 'screens/join_screen.dart';
import 'services/lan_network_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAN Game Hub',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      onHostTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HostScreen(
          onPlayerJoined: () {},
          onBackPressed: () {},
        )),
      ),
      onJoinTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JoinScreen(
          networkService: LANNetworkService(),
          onConnected: () {},
          onBackPressed: () {},
        )),
      ),
    );
  }
}
