import 'package:flutter/material.dart';

import '../common/common.dart';
import 'app_tile.dart';

class RadioListView extends StatelessWidget {
  final List<String> items;

  final Function(String) onTap;

  final ScrollController? scrollController;

  const RadioListView({
    Key? key,
    required this.items,
    required this.onTap,
     this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      controller: scrollController,
      itemBuilder: (context, index) {
        return _buildItem(items[index]);
      },
    );
  }

  Widget _buildItem(String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTile(
          label: value,
          onPressed: () => onTap(value),
          trailing: Radio<String>(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: value,
            groupValue: "",
            onChanged: (value) {},
          ),
        ),
        DividerSpace(),
      ],
    );
  }
}
