// lib/main.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:lantern/core/ffi/ffi_client.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:lantern/core/services/native_bridge.dart';

Color blue3 = HexColor('#00BCD4');
Color grey2 = HexColor('#F5F5F5');
Color grey3 = HexColor('#EBEBEB');
Color grey5 = HexColor('#707070');

Color onSwitchColor = blue3;
Color offSwitchColor = grey5;

class TunWidget extends ConsumerWidget {
  final bool isVPNRunning;

  final FFIClient ffiClient;
  final NativeBridge _nativeBridge = NativeBridge();

  TunWidget({required this.isVPNRunning, required this.ffiClient});

  Future<void> toggleSwitch(bool newValue, String vpnStatus) async {
    if (isVPNRunning) {
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
    String vpnStatus = isVPNRunning ? 'connected' : 'disconnected';
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
                activeColor: onSwitchColor,
                inactiveColor: grey3,
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
