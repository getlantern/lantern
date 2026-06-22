import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/localization/i18n.dart';

/// Spinner shown while a server is still awaiting its first url-test result.
/// Distinct from the unreachable warning: a server is "testing" until a probe
/// returns a verdict, and only "unreachable" once a probe has failed.
class ServerTestingIndicator extends StatelessWidget {
  const ServerTestingIndicator({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final label = 'server_testing'.i18n;
    final dimension = size ?? 16.0;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: SizedBox(
          width: dimension,
          height: dimension,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.textTertiary,
          ),
        ),
      ),
    );
  }
}
