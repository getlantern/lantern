import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

@RoutePage(name: 'Language')
class Language extends StatelessWidget {
  const Language({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text('language'.i18n)),
      extendBody: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: LanguageListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showLanguageBottomSheet(BuildContext context) {
  showAppBottomSheet(
      context: context,
      title: 'language'.i18n,
      builder: (context, scrollController) {
        return Expanded(
            child: LanguageListView(
          scrollController: scrollController,
        ));
      });
}

class LanguageListView extends HookConsumerWidget {
  final ScrollController? scrollController;

  LanguageListView({super.key, this.scrollController});

  late WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    this.ref = ref;
    final locale = ref.watch(appSettingNotifierProvider).locale;
    return ListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: languages
          .map((langCode) => _buildLanguageItem(langCode, locale.toLocale))
          .toList()
        ..add(SizedBox(height: 40)),
    );
  }

  Widget _buildLanguageItem(String langCode, Locale locale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTile(
          label: displayLanguage(langCode),
          onPressed: () => onLanguageTap(langCode),
          trailing: Radio<String>(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: langCode,
            groupValue: locale.toString(),
            onChanged: (value) {
              onLanguageTap(value!);
            },
            activeColor: AppColors.blue7,
          ),
          minHeight: 56,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerSpace(),
        ),
      ],
    );
  }

  void onLanguageTap(String language) {
    if (language.isEmpty) return;
    final newLocale =
        Locale(language.split('_').first, language.split('_').last);

    final result = ref
        .read(homeNotifierProvider.notifier)
        .updateLocale(newLocale.toString());

    result.then((either) {
      either.fold(
        (failure) {
          appLogger
              .error('Error updating locale: ${failure.localizedErrorMessage}');
        },
        (r) {
          appLogger.debug('Locale updated to: $newLocale');
        },
      );
    });

    ref
        .read(appSettingNotifierProvider.notifier)
        .setLocale(newLocale.toString());

    appRouter.maybePop();
  }
}
