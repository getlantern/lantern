import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';

// Provider to store search query
final searchQueryProvider = StateProvider<String>((ref) => "");

class AppSearchBar extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();

    return TextField(
      controller: searchController,
      onChanged: (value) => ref.read(searchQueryProvider.notifier).state =
          value, // Update search state
      decoration: InputDecoration(
        hintText: 'search_apps'.i18n,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: AppTestStyles.titleLarge.copyWith(
        color: Color(0xFF616569),
        height: 1.62,
      ),
    );
  }
}
