import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class LogsPath extends StatelessWidget {
  final List<String> logoPaths;

  const LogsPath({
    super.key,
    required this.logoPaths,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...logoPaths.map<Widget>(
          (p) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: SvgPicture.network(
                p,
                height: 30,
              ),
            ),
          ),
        )
      ],
    );
  }
}
