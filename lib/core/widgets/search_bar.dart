import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/features/split_tunneling/provider/search_query.dart';

class AppSearchBar extends AppBar {
  AppSearchBar({
    super.key,
    required WidgetRef ref,
    required String title,
    required String hintText,
    VoidCallback? onBack,
  }) : super(
          automaticallyImplyLeading: false,
          elevation: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SearchBarContent(
              ref: ref,
              title: title,
              hintText: hintText,
              onBack: onBack,
            ),
          ),
        );
}

class _SearchBarContent extends HookConsumerWidget {
  final String title;
  final String hintText;
  final VoidCallback? onBack;
  final WidgetRef ref;

  const _SearchBarContent({
    required this.title,
    required this.hintText,
    this.onBack,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSearching = useState(false);
    final controller = useTextEditingController();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: onBack ?? () => Navigator.pop(context),
        ),
        // Search input or title
        Expanded(
          child: isSearching.value
              ? TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (value) =>
                      ref.read(searchQueryProvider.notifier).setQuery(value),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: AppColors.gray7,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.gray9,
                  ),
                )
              : Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray9,
                  ),
                ),
        ),
        // Right icon (search or cancel)
        IconButton(
          icon: AppImage(
            path:
                isSearching.value ? AppImagePaths.close : AppImagePaths.search,
          ),
          onPressed: () {
            if (isSearching.value) {
              isSearching.value = false;
              controller.clear();
              ref.read(searchQueryProvider.notifier).setQuery("");
            } else {
              isSearching.value = true;
            }
          },
        ),
      ],
    );
  }
}
