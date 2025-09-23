import 'package:flutter/material.dart';

import '../common/common.dart';

class RadioListView<T> extends StatelessWidget {
  final List<T> items;
  final T? groupValue;
  final ValueChanged<T> onChanged;
  final Widget Function(T value, bool selected, VoidCallback onTap)? rowBuilder;
  final ScrollController? scrollController;

  const RadioListView({
    super.key,
    required this.items,
    required this.groupValue,
    required this.onChanged,
    this.rowBuilder,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      controller: scrollController,
      itemCount: items.length,
      separatorBuilder: (_, __) => const DividerSpace(),
      itemBuilder: (context, index) {
        final value = items[index];
        final selected = value == groupValue;
        if (rowBuilder != null) {
          return rowBuilder!(
            value,
            selected,
            () => onChanged(value),
          );
        }
        return AppTile(
          label: value.toString(),
          onPressed: () => onChanged(value),
          trailing: AppRadioButton<T>(
            value: value,
            groupValue: groupValue,
            onChanged: (v) => onChanged(value),
          ),
        );
      },
    );
  }
}
