import 'package:flutter/material.dart';

import '../common/common.dart';

// class RadioListView extends StatelessWidget {
//   final List<String> items;

//   final Function(String) onTap;

//   final ScrollController? scrollController;

//   const RadioListView({
//     Key? key,
//     required this.items,
//     required this.onTap,
//     this.scrollController,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return ListView.builder(
//       shrinkWrap: true,
//       itemCount: items.length,
//       controller: scrollController,
//       itemBuilder: (context, index) {
//         return _buildItem(items[index]);
//       },
//     );
//   }

//   Widget _buildItem(String value) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         AppTile(
//           label: value,
//           onPressed: () => onTap(value),
//           trailing: Radio<String>(
//             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//             value: value,
//             groupValue: "",
//             onChanged: (value) {},
//           ),
//         ),
//         DividerSpace(),
//       ],
//     );
//   }
// }

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
      separatorBuilder: (_, __) => DividerSpace(),
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
          trailing: Radio<T>(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: value,
            groupValue: groupValue,
            onChanged: (v) => onChanged(value),
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}
