import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

@RoutePage(name: 'QrCodeScanner')
class QrCodeScanner extends StatelessWidget {
  QrCodeScanner({super.key});

  final MobileScannerController controller =
      MobileScannerController(facing: CameraFacing.back);

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -100)),
      width: 300,
      height: 200,
    );
    return BaseScreen(
      title: 'qr_code_scanner'.i18n,
      appBar: AppBar(backgroundColor: Colors.transparent),
      padded: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              onDetect: (barcodes) {
                for (final barcode in barcodes.barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null) {
                    appLogger.info('Barcode found! $code');
                    controller.stop();
                    appRouter.pop(code);
                  }
                }
              },
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
              fit: BoxFit.fill,
            ),
          ),
          ScanWindowOverlay(
            scanWindow: scanWindow,
            color: AppColors.whiteBlur.withOpacity(.75),
            borderRadius: BorderRadius.circular(16),
            borderColor: AppColors.gray0,
            borderWidth: 4,
            controller: controller!,
          ),
        ],
      ),
    );
  }
}
