// lib/main.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:lantern/core/ffi/ffi_client.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:lantern/core/services/native_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

Color blue3 = HexColor('#00BCD4');
Color grey2 = HexColor('#F5F5F5');
Color grey3 = HexColor('#EBEBEB');
Color grey5 = HexColor('#707070');

Color onSwitchColor = blue3;
Color offSwitchColor = grey5;

class TunWidget extends HookConsumerWidget {
  final bool isVPNRunning;

  final FFIClient ffiClient;
  final NativeBridge _nativeBridge = NativeBridge();

  TunWidget({required this.isVPNRunning, required this.ffiClient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switchController = useState(isVPNRunning);

    Future<void> handleToggle(bool newValue) async {
      final error = await _toggleSwitch(context, newValue);
      // If we got an error message, revert the switch to OFF.
      if (error != null) {
        switchController.value = false;
      }
    }

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
                controller: switchController,
                width: 150,
                height: 70,
                borderRadius: BorderRadius.circular(40),
                disabledOpacity: 1,
                enabled: true,
                activeColor: onSwitchColor,
                inactiveColor: grey3,
                onChanged: (value) => handleToggle(value),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  /// Attempts to start/stop the VPN.
  Future<String?> _toggleSwitch(BuildContext context, bool newValue) async {
    String? error;
    if (!newValue) {
      // Turning VPN OFF
      if (Platform.isIOS) {
        error = await _nativeBridge.stopVPN();
      } else {
        error = ffiClient.stopVPN();
      }
    } else {
      // Turning VPN ON
      if (Platform.isIOS) {
        error = await _nativeBridge.startVPN();
      } else {
        error = ffiClient.startVPN();
      }
    }

    if (error != null) {
      // Show the error via a snack bar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("VPN Error: $error")),
      );
      return error; // Return the error so we know to revert the switch
    }
    return null;
  }
}
