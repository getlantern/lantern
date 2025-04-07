// Bullet point info rows
import 'package:flutter/widgets.dart';
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
                        style: AppTestStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        )),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTestStyles.bodyMedium.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
