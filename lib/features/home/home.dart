import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/ffi/ffi_client.dart';
import 'package:lantern/core/ffi/socket_client.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/providers/socket_provider.dart';
import 'package:lantern/core/vpn/widget.dart';
import 'package:lantern/core/widgets/custom_bottom_bar.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';

@RoutePage(name: 'Home')
class HomePage extends ConsumerStatefulWidget {
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final FFIClient _ffiClient;
  late final SocketClient _socketClient;
  late final StreamSubscription<bool> _vpnStatusSubscription;
  bool _isVPNRunning = false;

  @override
  void initState() {
    super.initState();
    // Initialize the socket client and connect
    _socketClient = ref.read(socketClientProvider);
    _socketClient.connect();

    // Initialize the ffi client with the socket client
    _ffiClient = ref.read(ffiClientProvider);

    // Listen to VPN status updates from the socket
    _vpnStatusSubscription = _socketClient.vpnStatusStream.listen((status) {
      setState(() {
        _isVPNRunning = status;
      });
    });
  }

  @override
  void dispose() {
    _vpnStatusSubscription.cancel();
    _socketClient.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = 'vpn';
    bool isOnboarded = true;
    return Scaffold(
      body: buildBody(tab, isOnboarded),
      bottomNavigationBar: CustomBottomBar(
        selectedTab: tab,
        isDevelop: !kReleaseMode,
      ),
    );
  }

  Widget buildBody(String selectedTab, bool? isOnboarded) {
    return TunWidget(isVPNRunning: _isVPNRunning, ffiClient: _ffiClient);
  }
}
