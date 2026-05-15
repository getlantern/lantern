import 'dart:async';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'QrCodeScanner')
class QrCodeScanner extends HookConsumerWidget {
  const QrCodeScanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guard against the reader firing onScan repeatedly while the QR is
    // in frame — we only want the first valid code, then pop the route.
    final isHandling = useRef(false);

    Future<void> handleCode(String code) async {
      try {
        appLogger.info('Barcode found'); // QR payload intentionally not logged
        if (!context.mounted) return;
        appRouter.pop(code);
      } finally {
        isHandling.value = false;
      }
    }

    return BaseScreen(
      title: 'scan_qr_code'.i18n,
      padded: false,
      body: ReaderWidget(
        // Lantern only scans its own private-server config QR — restrict
        // to QR Code format so we don't dispatch on stray UPC/EAN/etc.
        codeFormat: Format.qrCode,
        showGallery: false,
        showFlashlight: true,
        showToggleCamera: false,
        scanDelay: const Duration(milliseconds: 300),
        onScan: (Code result) {
          if (isHandling.value) return;
          final code = result.text;
          if (code == null || code.isEmpty) return;
          isHandling.value = true;
          unawaited(handleCode(code));
        },
        onScanFailure: (Code? result) {
          // Misreads fire continuously when there's no code in frame —
          // intentionally silent to keep logs clean.
        },
      ),
    );
  }
}
