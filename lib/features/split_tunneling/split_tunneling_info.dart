import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/bullet_list.dart';

@RoutePage(name: 'SplitTunnelingInfo')
class SplitTunnelingInfo extends HookConsumerWidget {
  const SplitTunnelingInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScreen(
      title: '',
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Text(
            'automatic_mode'.i18n,
            style: AppTestStyles.headingSmall.copyWith(
              color: Colors.black,
            ),
          ),
        ),
        actionsPadding: EdgeInsets.only(right: 16.0),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'split_tunneling_description'.i18n,
                    style: AppTestStyles.bodyLarge.copyWith(
                      height: 1.625,
                      color: AppColors.gray9,
                    ),
                  ),
                ),
                SubsectionTitle(
                    text: "🌍 ${'region_specific_rules'.i18n}", isLarge: true),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'location_based_rules'.i18n,
                    style: AppTestStyles.bodyLarge.copyWith(
                      height: 1.625,
                      color: AppColors.gray9,
                    ),
                  ),
                ),
                SubsectionTitle(icon: "🔒", text: 'censored_regions'.i18n),
                BulletList(
                  items: [
                    'blocked_sites_proxied'.i18n,
                    'unblocked_sites_bypass'.i18n,
                  ],
                  textStyle: AppTestStyles.bodyMedium.copyWith(
                    color: AppColors.gray8,
                    height: 1.5,
                  ),
                  bulletColor: AppColors.gray7,
                ),

                SubsectionTitle(icon: "✅", text: 'uncensored_regions'.i18n),
                BulletList(
                  items: [
                    'trusted_sites_bypass'.i18n,
                    'examples_of_bypassed_sites'.i18n,
                  ],
                  textStyle: AppTestStyles.bodyMedium.copyWith(
                    color: AppColors.gray8,
                    height: 1.5,
                  ),
                  bulletColor: AppColors.gray7,
                ),
                SizedBox(height: 16.0),
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

  const SectionTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: AppTestStyles.headingSmall),
    );
  }
}

// Smaller subsection heading
class SubsectionTitle extends StatelessWidget {
  final String text;
  final String? icon;
  final bool isLarge;

  const SubsectionTitle({
    super.key,
    required this.text,
    this.icon,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = isLarge
        ? Theme.of(context).textTheme.titleLarge!
        : AppTestStyles.labelMedium.copyWith(
            fontSize: 16,
            color: AppColors.gray9,
            fontWeight: FontWeight.w600,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                icon!,
                style: textStyle.copyWith(fontSize: 14),
              ),
            ),
          Flexible(
            child: Text(
              text,
              style: textStyle,
            ),
          ),
        ],
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
          TextSpan(
            text: prefix,
            style: AppTestStyles.bodyMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: linkLabel,
            style: AppTestStyles.bodyMedium.copyWith(
              color: AppColors.green11,
              fontSize: 16,
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
