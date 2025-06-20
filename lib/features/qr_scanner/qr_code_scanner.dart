import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

@RoutePage(name: 'QrCodeScanner')
class QrCodeScanner extends StatelessWidget {
  const QrCodeScanner({super.key});

  @override
  Widget build(BuildContext context) {
    MobileScannerController controller = MobileScannerController();
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -100)),
      width: 300,
      height: 200,
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.whiteBlur,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Stack(
        children: [
          MobileScanner(
            // useAppLifecycleState: false, // Only set to false if you want
            // to handle lifecycle changes yourself
            scanWindow: scanWindow,
            controller: controller,
            errorBuilder: (context, error) {
              return Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            },
            fit: BoxFit.contain,
          ),
          ScanWindowOverlay(
            scanWindow: scanWindow,
            controller: controller!,
          ),
        ],
      ),
    );
  }
}
