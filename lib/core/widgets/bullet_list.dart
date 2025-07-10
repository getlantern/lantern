// Bullet point info rows
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class BulletList extends StatelessWidget {
  final List<String> items;
  const BulletList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        //separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) => ListTile(
          //contentPadding: const EdgeInsets.only(bottom: 8.0),
          title: Text(
            "· ${items[i]}",
            style: AppTestStyles.bodyLarge,
          ),
          onTap: () => Navigator.of(ctx).pop(items[i]),
        ),
      ),
    );
  }
}
