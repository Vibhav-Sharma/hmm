import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lan_network_service.dart';

/// Host screen where a player waits for another player to join
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
  final LANNetworkService _networkService = LANNetworkService();
  String? _localIp;
  bool _isLoading = true;
  String _statusMessage = 'Starting server...';

  @override
  void initState() {
    super.initState();
    _initializeHost();
  }

  /// Initialize hosting server
  Future<void> _initializeHost() async {
    try {
      // Start hosting
      final serverUrl = await _networkService.startHosting();

      if (serverUrl != null) {
        final ip = await _networkService.getLocalIp();

        // Set up callbacks
        _networkService.onPlayerJoined = _onPlayerJoined;

        setState(() {
          _localIp = ip;
          _isLoading = false;
          _statusMessage = 'Waiting for player...';
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: Could not start server';
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  /// Called when a player joins
  void _onPlayerJoined() {
    print('Player joined!');
    setState(() {
      _statusMessage = 'Player connected! Starting game...';
    });

    // Navigate to game screen after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        widget.onPlayerJoined();
      }
    });
  }

  /// Copy IP to clipboard
  void _copyToClipboard() {
    if (_localIp != null) {
      Clipboard.setData(ClipboardData(text: _localIp!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IP address copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _networkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _networkService.stopHosting();
        widget.onBackPressed();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Host Game'),
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _networkService.stopHosting();
              widget.onBackPressed();
            },
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status Indicator
                  if (_isLoading)
                    const SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 4,
                      ),
                    )
                  else
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.shade400,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade400.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Status Message
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // IP Display Card
                  if (_localIp != null && !_isLoading)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Share this IP with other player:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.shade300,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              _localIp!,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _copyToClipboard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.copy, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Copy IP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Connected Players Info
                  if (!_isLoading)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Connected Players: ${_networkService.connectedClientCount}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _networkService.connectedClientCount > 0
                                ? 'Ready to play!'
                                : 'Waiting for player...',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
