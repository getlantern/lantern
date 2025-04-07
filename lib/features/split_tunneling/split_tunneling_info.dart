import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_mode.dart';
import 'package:lantern/core/widgets/bullet_list.dart';

@RoutePage(name: 'SplitTunnelingInfo')
class SplitTunnelingInfo extends HookConsumerWidget {
  const SplitTunnelingInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider).value;
    final splitTunnelingEnabled =
        preferences?[Preferences.splitTunnelingEnabled] ?? false;
    final splitTunnelingMode = preferences?[Preferences.splitTunnelingMode] ??
        SplitTunnelingMode.automatic;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('automatic'.i18n, style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      body: AppCard(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                DescriptionText(text: 'split_tunneling_description'.i18n),
                SubsectionTitle(
                    text: "🌍 ${'region_specific_rules'.i18n}", isLarge: true),
                DescriptionText(text: 'location_based_rules'.i18n),
                SubsectionTitle(text: "🔒 ${'censored_regions'.i18n}"),
                BulletList(items: [
                  'blocked_sites_proxied'.i18n,
                  'unblocked_sites_bypass'.i18n,
                ]),

                SubsectionTitle(text: "✅ ${'uncensored_regions'.i18n}"),
                BulletList(items: [
                  'trusted_sites_bypass'.i18n,
                  'examples_of_bypassed_sites'.i18n,
                ]),
                LinkText(
                  prefix: 'routing_rules_vary'.i18n,
                  linkLabel: 'view_the_full_list'.i18n,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: AppTestStyles.headingSmall),
    );
  }
}

class DescriptionText extends StatelessWidget {
  final String text;
  const DescriptionText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: AppTestStyles.bodyMedium.copyWith(
          color: AppColors.gray7,
          height: 1.6,
        ),
      ),
    );
  }
}

// Smaller subsection heading
class SubsectionTitle extends StatelessWidget {
  final String text;
  final bool isLarge;

  const SubsectionTitle({Key? key, required this.text, this.isLarge = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Text(
        text,
        style: isLarge
            ? AppTestStyles.titleLarge
            : AppTestStyles.labelLarge.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
      ),
    );
  }
}

class LinkText extends StatelessWidget {
  final String prefix;
  final String linkLabel;
  final VoidCallback? onTap;

  const LinkText({
    super.key,
    required this.prefix,
    required this.linkLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTestStyles.bodyMedium,
        children: [
          TextSpan(text: '$prefix '),
          TextSpan(
            text: linkLabel,
            style: AppTestStyles.bodyMedium.copyWith(
              color: AppColors.green11,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = onTap,
          ),
        ],
      ),
    );
  }
}
