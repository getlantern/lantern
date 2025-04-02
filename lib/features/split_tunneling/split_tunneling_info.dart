import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'SplitTunnelingInfo')
class SplitTunnelingInfo extends HookConsumerWidget {
  const SplitTunnelingInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: Card(
        borderOnForeground: false,
        color: Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(0),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                InfoText(text: 'location_based_rules'.i18n),
                SubsectionTitle(text: 'censored_regions'.i18n),
                InfoText(text: 'blocked_sites_proxied'.i18n),
                InfoText(text: 'unblocked_sites_bypass'.i18n),
                SubsectionTitle(text: 'uncensored_regions'.i18n),
                InfoText(text: 'trusted_sites_bypass'.i18n),
                InfoText(text: 'examples_of_bypassed_sites'.i18n),
                InfoText(text: 'routing_rules_country'.i18n),
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

// Smaller subsection heading
class SubsectionTitle extends StatelessWidget {
  final String text;
  const SubsectionTitle({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(text, style: AppTestStyles.titleSmall),
    );
  }
}

// Bullet point info rows
class InfoText extends StatelessWidget {
  final String text;
  const InfoText({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: AppTestStyles.bodyLarge),
          Expanded(
            child: Text(text, style: AppTestStyles.bodyLarge),
          ),
        ],
      ),
    );
  }
}
