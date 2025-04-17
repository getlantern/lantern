// Bullet point info rows
import 'package:flutter/widgets.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class BulletList extends StatelessWidget {
  final List<String> items;
  const BulletList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("· ",
                        style: AppTestStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w400,
                        )),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTestStyles.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
