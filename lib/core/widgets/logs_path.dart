import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

const _iconSpace = SizedBox(width: 44, height: 30);

/// Payment icons shipped with the app. The server sends icon URLs on a CDN
/// that is often unreachable from China, so known ones render from assets.
const _bundledPaymentIcons = {
  'alipay',
  'mastercard',
  'unionpay',
  'visa',
  'wechatpay',
};

/// The bundled asset for a server icon URL, or null if none is bundled.
String? bundledPaymentIcon(String url) {
  final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
  if (segments.isEmpty || !segments.last.endsWith('.svg')) return null;
  final name = segments.last.substring(0, segments.last.length - 4);
  return _bundledPaymentIcons.contains(name)
      ? 'assets/images/payments/$name.svg'
      : null;
}

class LogsPath extends StatelessWidget {
  final List<String> logoPaths;

  const LogsPath({super.key, required this.logoPaths});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...logoPaths.map<Widget>((p) {
          final asset = bundledPaymentIcon(p);
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: asset != null
                ? SvgPicture.asset(asset, height: 30)
                : SvgPicture.network(
                    p,
                    height: 30,
                    placeholderBuilder: (_) => _iconSpace,
                    errorBuilder: (_, _, _) => _iconSpace,
                  ),
          );
        }),
      ],
    );
  }
}
