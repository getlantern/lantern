import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/localization/localization_constants.dart';

@RoutePage(name: 'Language')
class Language extends StatelessWidget {
  const Language({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'language'.i18n),
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

class LanguageListView extends StatelessWidget {
  final ScrollController? scrollController;

  const LanguageListView({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      controller: scrollController,
      padding: EdgeInsets.zero,
      children:
          languages.map((langCode) => _buildLanguageItem(langCode)).toList()
            ..add(SizedBox(height: 40)),
    );
  }

  Widget _buildLanguageItem(String langCode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTile(
          label: displayLanguage(langCode),
          onPressed: () => onLanguageTap(langCode),
          trailing: Radio<String>(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: langCode,
            groupValue: "",
            onChanged: (value) {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerSpace(),
        ),
      ],
    );
  }

  void onLanguageTap(String language) {
    appRouter.maybePop();
  }
}
