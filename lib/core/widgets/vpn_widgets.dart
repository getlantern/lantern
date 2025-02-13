// lib/main.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/ffi/ffi_client.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:lantern/core/services/native_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';



class TunWidget extends HookConsumerWidget {
  final bool isVPNRunning;

  final FFIClient ffiClient;
  final NativeBridge _nativeBridge = NativeBridge();

  TunWidget({required this.isVPNRunning, required this.ffiClient});

  Future<void> toggleSwitch(bool newValue, String vpnStatus) async {
    if (!newValue) {
      if (Platform.isIOS) {
        await _nativeBridge.stopVPN();
      } else {
        ffiClient.stopVPN();
      }
    } else {
      if (Platform.isIOS) {
        await _nativeBridge.startVPN();
      } else {
        ffiClient.startVPN();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize ffi client
    final _ffiClient = ref.read(ffiClientProvider);
    String vpnStatus =
        _ffiClient.isVPNConnected() == 1 ? 'connected' : 'disconnected';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              AdvancedSwitch(
                width: 150,
                height: 70,
                borderRadius: BorderRadius.circular(40),
                disabledOpacity: 1,
                enabled: true,
                initialValue: isVPNRunning,
                activeColor: Colors.teal,
                inactiveColor: Colors.black,
                onChanged: (value) => toggleSwitch(value, vpnStatus),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
}
