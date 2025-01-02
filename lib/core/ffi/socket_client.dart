import 'dart:async';
import 'dart:io';

class SocketClient {
  final String host;
  final int port;
  Socket? _socket;
  final StreamController<bool> _vpnStatusController =
      StreamController<bool>.broadcast();

  SocketClient({required this.host, required this.port});

  Stream<bool> get vpnStatusStream => _vpnStatusController.stream;

  Future<void> connect() async {
    try {
      print('Connecting to VPN server at $host:$port');
      _socket = await Socket.connect(host, port);
      print('Connected to VPN server at $host:$port');

      _socket!.listen(
        (data) {
          String message = String.fromCharCodes(data).trim();
          print('Received: $message');
          if (message.contains('disconnected')) {
            _vpnStatusController.add(false);
          } else if (message.contains('connected')) {
            _vpnStatusController.add(true);
          }
        },
        onDone: () {
          print('Disconnected from VPN server');
          _vpnStatusController.add(false);
        },
        onError: (error) {
          print('Socket error: $error');
          _vpnStatusController.add(false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('Failed to connect: $e');
      _vpnStatusController.add(false);
    }
  }

  void disconnect() {
    _socket?.destroy();
    _vpnStatusController.close();
  }
}
