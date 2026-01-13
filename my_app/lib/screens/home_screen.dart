import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onHostTap;
  final VoidCallback onJoinTap;

  const HomeScreen({
    Key? key,
    required this.onHostTap,
    required this.onJoinTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'LAN Game Hub',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: onHostTap,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text('Host Game', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onJoinTap,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text('Join Game', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
