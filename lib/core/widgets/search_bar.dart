import 'package:flutter/material.dart' hide BackButton;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/core/widgets/app_focusable.dart';
import 'package:lantern/core/widgets/custom_app_bar.dart';
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
          // On TV the arrow sits where every other screen's does: the same
          // widget, in the leading slot, on the 44dp bar.
          leading: PlatformUtils.tvShellEnabled ? const BackButton() : null,
          toolbarHeight: PlatformUtils.tvShellEnabled
              ? tvToolbarHeight
              : kToolbarHeight,
          elevation: 0,
          title: Padding(
            padding: PlatformUtils.tvShellEnabled
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16),
            child: _SearchBarContent(
              ref: ref,
              title: title,
              hintText: hintText,
              onBack: onBack,
              showBack: !PlatformUtils.tvShellEnabled,
            ),
          ),
        );
}

class _SearchBarContent extends HookConsumerWidget {
  final String title;
  final String hintText;
  final VoidCallback? onBack;
  final WidgetRef ref;
  final bool showBack;

  const _SearchBarContent({
    required this.title,
    required this.hintText,
    this.onBack,
    required this.ref,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSearching = useState(false);
    final controller = useTextEditingController();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showBack)
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
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: context.textPrimary,
                  ),
                )
              : Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
        ),
        // Right icon (search or cancel). A TV screen opens on its first row,
        // not on this button; it is still reachable with the D-pad.
        TvNotInitialFocus(
          child: IconButton(
            icon: AppImage(
              path: isSearching.value
                  ? AppImagePaths.close
                  : AppImagePaths.search,
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
        ),
      ],
    );
  }
}
