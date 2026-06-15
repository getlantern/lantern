import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _appName = String.fromEnvironment(
  'APP_LABEL',
  defaultValue: 'Mobile App',
);
const _localProxyMode = bool.fromEnvironment('LOCAL_PROXY');
const _proxyHost = String.fromEnvironment(
  'LOCAL_PROXY_HOST',
  defaultValue: '127.0.0.1',
);
const _proxyPort = int.fromEnvironment('LOCAL_PROXY_PORT', defaultValue: 14986);

void main() {
  runApp(const StealthApp());
}

class StealthApp extends StatelessWidget {
  const StealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2f6f6d),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const StealthHome(),
    );
  }
}

class StealthHome extends StatefulWidget {
  const StealthHome({super.key});

  @override
  State<StealthHome> createState() => _StealthHomeState();
}

class _StealthHomeState extends State<StealthHome> {
  static const _channel = MethodChannel('foundation.bridge/control');
  String _state = 'disconnected';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final state = await _channel.invokeMethod<String>('state');
      if (!mounted) return;
      setState(() {
        _state = state ?? 'disconnected';
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _invoke(String method) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _channel.invokeMethod<void>(method);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _state == 'connected';
    final color = switch (_state) {
      'connected' => const Color(0xff2e7d32),
      'connecting' => const Color(0xff1565c0),
      _ => const Color(0xff757575),
    };

    return Scaffold(
      appBar: AppBar(title: Text(_appName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _labelForState(_state),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy || connected ? null : () => _invoke('connect'),
              icon: _busy && !connected
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('Connect'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy || !connected
                  ? null
                  : () => _invoke('disconnect'),
              icon: const Icon(Icons.stop),
              label: const Text('Disconnect'),
            ),
            if (_localProxyMode) ...[
              const SizedBox(height: 32),
              Text(
                'Manual setup',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Type', value: 'SOCKS5'),
              _InfoRow(label: 'Host', value: _proxyHost),
              _InfoRow(label: 'Port', value: '$_proxyPort'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 24),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelForState(String state) {
    return switch (state) {
      'connected' => 'Connected',
      'connecting' => 'Connecting',
      'disconnecting' => 'Disconnecting',
      _ => 'Disconnected',
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
