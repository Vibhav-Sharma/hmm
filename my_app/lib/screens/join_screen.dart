import 'package:flutter/material.dart';
import '../services/lan_network_service.dart';

/// Join screen where a player enters the host IP to connect
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
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;
  String _errorMessage = '';

  /// Connect to the host server
  Future<void> _connectToHost() async {
    final ip = _ipController.text.trim();

    // Validation
    if (ip.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an IP address';
      });
      return;
    }

    if (!_isValidIp(ip)) {
      setState(() {
        _errorMessage = 'Invalid IP address format';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = '';
    });

    try {
      // Attempt to connect to the host
      final connected = await widget.networkService.connectToHost(ip);

      if (connected && mounted) {
        // Connection successful
        setState(() {
          _isConnecting = false;
        });

        // Navigate to game screen
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            widget.onConnected();
          }
        });
      } else if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = 'Failed to connect to host. Check the IP address.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  /// Validate IP address format
  bool _isValidIp(String ip) {
    // Simple validation: check if it looks like an IP address
    final ipPattern = RegExp(
      r'^(\d{1,3}\.){3}\d{1,3}$',
    );
    return ipPattern.hasMatch(ip);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onBackPressed();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Join Game'),
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBackPressed,
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
                  // Illustration
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.link,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Connect to Host',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'Enter the host\'s IP address',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // IP Input Field
                  Container(
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
                    child: TextField(
                      controller: _ipController,
                      enabled: !_isConnecting,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                      decoration: InputDecoration(
                        hintText: '192.168.1.100',
                        hintStyle: TextStyle(
                          color: Colors.blue.shade300,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_errorMessage.isNotEmpty) const SizedBox(height: 24),

                  // Connect Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isConnecting ? null : _connectToHost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade500,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                      ),
                      child: _isConnecting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 3,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Connecting...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 24, color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                  'Connect',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Help Text
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
                        const Icon(Icons.help_outline,
                            color: Colors.white, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          'Ask the host player for their IP address. It looks like 192.168.X.X',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
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
